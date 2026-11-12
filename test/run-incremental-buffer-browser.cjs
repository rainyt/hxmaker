// 使用真实 Chrome WebGL 提交，测试脚本逐帧完成像素对照。
const { chromium } = require(process.env.HXMAKER_PLAYWRIGHT_MODULE || 'playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

async function main() {
  const root = path.resolve(__dirname, '..');
  const server = http.createServer((request, response) => {
    if (request.url === '/favicon.ico') { response.writeHead(204); response.end(); return; }
    if (request.url === '/') {
      response.setHeader('Content-Type', 'text/html');
      response.end('<html><body style="margin:0"><script src="/bin/incremental-buffer-browser.js"></script></body></html>');
      return;
    }
    if (request.url !== '/bin/incremental-buffer-browser.js') { response.writeHead(404); response.end(); return; }
    response.setHeader('Content-Type', 'application/javascript');
    response.end(fs.readFileSync(path.join(root, 'bin/incremental-buffer-browser.js')));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: process.env.HXMAKER_CHROME || (process.platform === 'darwin'
        ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : undefined),
      headless: true,
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader']
    });
    const page = await browser.newPage({ viewport: { width: 384, height: 192 }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    await page.waitForFunction(() => window.bufferResult, null, { timeout: 30000 });
    const result = await page.evaluate(() => window.bufferResult);
    if (result.error || errors.length) throw new Error(JSON.stringify({ result, errors }));
    console.log(JSON.stringify(result));
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
