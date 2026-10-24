import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { gzipSync } from 'node:zlib';

/** 使用独立 Chrome 的本地 CDP 接口；无需安装 npm 依赖。 */
class CDP {
  constructor(socket) {
    this.socket = socket;
    this.next = 0;
    this.pending = new Map();
    this.events = [];
    socket.onmessage = ({ data }) => {
      const message = JSON.parse(data);
      if (message.id) {
        const waiter = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) waiter.reject(new Error(JSON.stringify(message.error)));
        else waiter.resolve(message.result);
      } else if (['Runtime.exceptionThrown', 'Runtime.consoleAPICalled', 'Log.entryAdded'].includes(message.method)) {
        this.events.push(message);
      }
    };
  }
  static async connect(url) {
    const socket = new WebSocket(url);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    return new CDP(socket);
  }
  call(method, params = {}) {
    const id = ++this.next;
    return new Promise((resolve, reject) => { this.pending.set(id, { resolve, reject }); this.socket.send(JSON.stringify({ id, method, params })); });
  }
  async evaluate(expression) {
    const result = await this.call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  }
  close() { this.socket.close(); }
}

const args = Object.fromEntries(process.argv.slice(2).map(value => value.replace(/^--/, '').split('=')));
const suite = args.suite || 'smoke';
const directory = path.resolve(args.output || `results/${suite}`);
await fs.mkdir(directory, { recursive: true });
const endpoint = args.cdp || 'http://127.0.0.1:9223';
const version = await (await fetch(`${endpoint}/json/version`)).json();
const browser = await CDP.connect(version.webSocketDebuggerUrl);
const gpu = await browser.call('SystemInfo.getInfo');
const targets = await (await fetch(`${endpoint}/json/list`)).json();
const target = targets.find(value => value.type === 'page');
if (!target) throw new Error('独立 Chrome 中没有页面');
const cdp = await CDP.connect(target.webSocketDebuggerUrl);
await cdp.call('Page.enable');
await cdp.call('Runtime.enable');
await cdp.call('Log.enable');
await cdp.call('Emulation.setDeviceMetricsOverride', { width: 960, height: 640, deviceScaleFactor: Number(args.dpr || 1), mobile: false });
await cdp.call('Page.bringToFront');
const metadata = { date: new Date().toISOString(), browser: version, gpu: gpu.gpu, platform: os.platform(), arch: os.arch(), cpus: os.cpus()[0]?.model, suite };
await fs.writeFile(path.join(directory, 'environment.json'), JSON.stringify(metadata, null, 2));

const cases = suite === 'performance'
  ? [10000, 50000].flatMap(count => [1, 6].map(textures => ({ count, textures, scenario: 'moving', warmup: 3000, duration: 7000 })))
  : suite === 'diagnostic'
    ? [10000, 50000].flatMap(count => [1, 6].map(textures => ({ count, textures, scenario: 'moving', warmup: 1000, duration: 2000, diagnostic: 1 })))
    : [{ count: 160, textures: 6, scenario: 'correctness', warmup: 500, duration: 500 },
       { count: 20000, textures: 6, scenario: 'moving', warmup: 500, duration: 500 },
       { count: 1000, textures: 1, scenario: 'rebuild', warmup: 500, duration: 500 },
       { count: 160, textures: 6, scenario: 'cache', warmup: 500, duration: 500 },
       { count: 50000, textures: 6, scenario: 'static', warmup: 500, duration: 500 },
       { count: 1000, textures: 6, scenario: 'static', warmup: 500, duration: 500 }];
const repetitions = Number(args.runs || (suite === 'performance' ? 5 : 1));
const results = [];
for (let round = 0; round < repetitions; round++) {
  for (const specification of cases.filter(value => !args.scenario || value.scenario === args.scenario)) {
    const order = round % 2 ? ['direct', 'graphics'] : ['graphics', 'direct'];
    for (const mode of order) {
      cdp.events.length = 0;
      const filename = mode === 'graphics' ? 'baseline.html' : 'index.html';
      const parameters = new URLSearchParams({ ...specification, mode });
      const url = `http://127.0.0.1:8765/${filename}?${parameters}`;
      await cdp.call('Page.navigate', { url });
      const deadline = Date.now() + specification.warmup + specification.duration + 30000;
      let finished = false;
      while (Date.now() < deadline) {
        await new Promise(resolve => setTimeout(resolve, 250));
        const failure = cdp.events.find(event => event.method === 'Runtime.exceptionThrown');
        if (failure) throw new Error(JSON.stringify(failure));
        try { finished = await cdp.evaluate('Boolean(window.__benchmark && window.__benchmark.done)'); }
        catch { continue; }
        if (finished) break;
      }
      if (!finished) throw new Error(`采样超时：${url}\n${JSON.stringify(cdp.events)}`);
      const result = await cdp.evaluate('window.__benchmark.result');
      const raw = await cdp.evaluate('window.__benchmark.raw()');
      const entry = { round, ...result, events: [...cdp.events] };
      results.push(entry);
      const stem = `${round}-${mode}-${specification.count}-${specification.textures}-${specification.scenario}`;
      await fs.writeFile(path.join(directory, `${stem}.json`), JSON.stringify(entry, null, 2));
      await fs.writeFile(path.join(directory, `${stem}-frames.json.gz`), gzipSync(JSON.stringify(raw)));
      if (suite === 'smoke' || suite === 'context') {
        await cdp.evaluate("document.getElementById('benchmark-result')?.remove()");
        const screenshot = await cdp.call('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
        await fs.writeFile(path.join(directory, `${stem}.png`), Buffer.from(screenshot.data, 'base64'));
        if (suite === 'context') {
          await cdp.evaluate('window.__benchmark.restoreContext()');
          const restored = await cdp.call('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
          await fs.writeFile(path.join(directory, `${stem}-restored.png`), Buffer.from(restored.data, 'base64'));
        }
      }
      console.log(JSON.stringify({ round, mode, count: specification.count, textures: specification.textures, scenario: specification.scenario,
        frames: result.frames, frameCpu: result.metrics.frameCpu.mean, p95: result.metrics.frameCpu.p95, fps: result.fps,
        draws: result.metrics.draws?.mean, uploadBytes: result.metrics.uploadBytes?.mean }));
      await fs.writeFile(path.join(directory, 'results.json'), JSON.stringify(results, null, 2));
    }
  }
}
cdp.close(); browser.close();
