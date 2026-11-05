import { CDP } from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import os from 'node:os';

// 所有等待都有期限；失败保留截图和结构化报告。
const output = new URL('../results/', import.meta.url);
await fs.mkdir(output, { recursive: true });
const endpoint = process.env.CDP_ENDPOINT || 'http://127.0.0.1:9425';
const version = await (await fetch(`${endpoint}/json/version`)).json();
const browser = await CDP.connect(version.webSocketDebuggerUrl);
const gpu = await browser.call('SystemInfo.getInfo');
const targets = await (await fetch(`${endpoint}/json/list`)).json();
const cdp = await CDP.connect(targets.find(x => x.type === 'page').webSocketDebuggerUrl);
await cdp.call('Page.enable'); await cdp.call('Runtime.enable'); await cdp.call('Log.enable');
await cdp.call('Network.enable'); await cdp.call('Network.setCacheDisabled', { cacheDisabled: true });
await cdp.call('Performance.enable');
await cdp.call('Emulation.setDeviceMetricsOverride', { width: 960, height: 640, deviceScaleFactor: 1, mobile: false });
await cdp.call('Page.addScriptToEvaluateOnNewDocument', { source: `(() => {
  const stats = window.__gpuStats = {created:0,deleted:0,live:0,peak:0,losses:0};
  const original = HTMLCanvasElement.prototype.getContext;
  const seen = new WeakSet();
  HTMLCanvasElement.prototype.getContext = function(...args) {
    const gl = original.apply(this,args);
    if (!gl || !gl.createTexture || seen.has(gl)) return gl;
    seen.add(gl); const live = new Set();
    const create = gl.createTexture, destroy = gl.deleteTexture;
    gl.createTexture = function(...a) { const t = create.apply(gl,a); if(t) { live.add(t); stats.created++; stats.live=live.size; stats.peak=Math.max(stats.peak,stats.live); } return t; };
    gl.deleteTexture = function(t) { if(live.delete(t)) stats.deleted++; stats.live=live.size; return destroy.call(gl,t); };
    this.addEventListener('webglcontextlost',e=>{e.preventDefault();live.clear();stats.live=0;stats.losses++;});
    return gl;
  };
})()` });
const report = { createdAt: new Date().toISOString(), platform: os.platform(), arch: os.arch(), version, gpu: gpu.gpu, passed: false, checkpoints: [], screenshots: [] };
const start = Date.now();
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(expression, ms = 10000) {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    if (await cdp.evaluate(expression)) return;
    await pause(50);
  }
  throw new Error(`等待超时：${expression}`);
}
async function frames(count = 3) {
  await cdp.evaluate(`new Promise(resolve=>{let n=${count};function frame(){if(--n<=0)resolve();else requestAnimationFrame(frame);}requestAnimationFrame(frame);})`);
}
async function shot(name) {
  const result = await cdp.call('Page.captureScreenshot', { format: 'png' });
  await fs.writeFile(new URL(name, output), Buffer.from(result.data, 'base64'));
  report.screenshots.push(name);
}
async function checkpoint(name) {
  await cdp.call('HeapProfiler.collectGarbage');
  const state = await cdp.evaluate('({state:window.__stability.snapshot(),gpu:window.__gpuStats,heap:performance.memory?.usedJSHeapSize})');
  report.checkpoints.push({name,...state});
  console.log(JSON.stringify({name,...state}));
  return state;
}
try {
  await cdp.call('Page.navigate', { url: `http://127.0.0.1:8876/?run=${start}` });
  await waitFor('Boolean(window.__stability?.ready)');
  await waitFor('!window.__stability.snapshot().astc.enabled || window.__stability.snapshot().astc.ready'); await frames(10);
  cdp.events.length = 0;
  const initial = await checkpoint('初始');
  assert.equal(initial.state.diagnostics.faults,0);
  assert.equal(initial.state.checks.length,8);
  await shot('initial.png');
  await cdp.evaluate('window.__stability.masks(false)'); await frames(); await shot('masks-off.png');
  await cdp.evaluate('window.__stability.masks(true)'); await frames(); await shot('masks-on.png');
  for(const count of [16,8,1,16,1,0]) {
    await cdp.evaluate(`window.__stability.textures(${count})`); await frames();
    assert.equal((await cdp.evaluate('window.__stability.snapshot()')).diagnostics.faults,0);
    await shot(`textures-${count}.png`);
  }
  for(const count of [1,8,16]) { await cdp.evaluate(`window.__stability.compiled(${count})`); await frames(); await shot(`compiled-${count}.png`); }
  await cdp.evaluate('window.__stability.textures(0)'); await frames();
  for(let i=0;i<100;i++) {
    await cdp.evaluate('window.__stability.foreground(false)'); await frames(1);
    await cdp.evaluate('window.__stability.foreground(true)'); await frames(1);
  }
  assert.equal((await cdp.evaluate('window.__stability.snapshot()')).generation,0);
  await checkpoint('模拟前后台一百轮'); await shot('after-foreground.png');
  for(let i=0;i<30;i++) {
    for(const [width,height] of [[800,600],[480,800],[1280,720]]) {
      await cdp.call('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});
      await cdp.evaluate(`window.__stability.resize(${width},${height})`); await frames(2);
      const size=await cdp.evaluate('window.__stability.snapshot()'); assert.equal(size.windowWidth,width); assert.equal(size.windowHeight,height);
    }
  }
  await cdp.call('Emulation.setDeviceMetricsOverride',{width:960,height:640,deviceScaleFactor:1,mobile:false}); await frames(5);
  await cdp.evaluate('window.__stability.resize(960,640)'); await frames(5);
  await cdp.evaluate('window.__stability.memory()'); await frames();
  const resized=await checkpoint('尺寸变化九十次'); assert.equal(resized.state.diagnostics.faults,0);
  assert.ok(resized.state.diagnostics.drawn>1000,'尺寸事件没有进入实际渲染');
  await shot('after-resize.png');
  await cdp.evaluate('window.__stability.step()'); await frames(); await shot('single-red.png');
  await cdp.evaluate('window.__stability.step()'); await frames(); await shot('single-blue.png');
  await cdp.evaluate('window.__stability.step()'); await frames();
  for (let i=1;i<=200;i++) {
    for(let phase=0;phase<3;phase++) { await cdp.evaluate('window.__stability.step()'); await frames(2); }
    if([10,50,100,200].includes(i)) {
      await cdp.evaluate('window.__stability.clean()');
      const current = await checkpoint(`切换${i}轮`);
      assert.equal(current.state.diagnostics.faults,0);
      assert.equal(current.state.diagnostics.pendingDisposals,0);
      assert.equal(current.state.diagnostics.references,initial.state.diagnostics.references);
    }
  }
  await shot('after-200-cycles.png');
  await pause(10500); await cdp.evaluate('window.__stability.clean()'); await frames();
  await checkpoint('静止十秒后清理'); await shot('after-idle-clean.png');
  for(let i=1;i<=20;i++) {
    const before = await cdp.evaluate('window.__stability.snapshot().recovered');
    assert.equal(await cdp.evaluate('window.__stability.lose()'),true,'设备不支持上下文丢失注入');
    await waitFor(`window.__stability.snapshot().recovered>${before} && !window.__stability.snapshot().lost`,10000);
    await frames(6);
    const current = await cdp.evaluate('window.__stability.snapshot()');
    assert.equal(current.diagnostics.faults,0);
    if(i===1 || i===20) { await checkpoint(`恢复${i}轮`); await shot(`restored-${i}.png`); }
  }
  await cdp.evaluate('window.__stability.inject("disposed")'); await frames(10);
  const injected = await checkpoint('原生误释放注入');
  assert.ok(injected.state.diagnostics.faults>0);
  assert.equal(injected.state.diagnostics.reports[0].kind,'disposed');
  assert.equal(injected.state.diagnostics.reports.length,1);
  await shot('fault-isolated.png');
  await cdp.evaluate('window.__stability.clearFault()'); await frames(10);
  await shot('after-fault.png');
  for(const kind of ['invalidSize','uploadFailed','missingRecovery']) {
    await cdp.evaluate(`window.__stability.inject('${kind}')`); await frames(5);
    const state=await cdp.evaluate('window.__stability.snapshot()');
    assert.ok(state.diagnostics.reports.some(x=>x.kind===kind),`没有分类 ${kind}`);
    await cdp.evaluate('window.__stability.clearFault()'); await frames(3);
  }
  await cdp.evaluate('window.__stability.feedback()'); await frames(5);
  const feedback=await cdp.evaluate('window.__stability.snapshot()');
  assert.ok(feedback.diagnostics.reports.some(x=>x.kind==='feedback'));
  await shot('after-all-faults.png');
  const final = await checkpoint('最终');
  assert.equal(final.state.diagnostics.references,initial.state.diagnostics.references);
  const exceptions=cdp.events.filter(x=>x.method==='Runtime.exceptionThrown');
  assert.equal(exceptions.length,0,JSON.stringify(exceptions));
  report.passed=true;
} catch(error) {
  report.error=String(error.stack||error); await shot('failed.png'); throw error;
} finally {
  report.events=cdp.events.filter(x=>x.method==='Runtime.exceptionThrown'||(x.method==='Log.entryAdded'&&x.params.entry.level==='error'));
  report.elapsedMilliseconds=Date.now()-start;
  await fs.writeFile(new URL('report.json',output),JSON.stringify(report,null,2));
  cdp.close(); browser.close();
}
