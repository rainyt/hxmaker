// 本地浏览器回归：先构建带验收宏的示例，并从仓库根启动静态 HTTP 服务。
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.HXMAKER_TEST_BASE || 'http://127.0.0.1:8731';
const cases = [
  ['terrain-character', ['HXMAKER_COLLISION_CHECKS PASS', 'HXMAKER_TERRAIN_CHECKS PASS']],
  ['textured-character', ['HXMAKER_CHARACTER_CHECKS PASS', 'HXMAKER_ANIMATION_SOCKET_CHECKS PASS']],
  ['camera-interaction', ['HXMAKER_CAMERA_INTERACTION_CHECKS PASS']],
  ['navigation-character', ['HXMAKER_NAV_AGENT_CHECKS PASS', 'HXMAKER_NAV_SAMPLE_CHECKS PASS']]
];
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, label, timeout = 20000) {
  const end = Date.now() + timeout;
  while (!predicate() && Date.now() < end) await sleep(100);
  assert(predicate(), '等待超时：' + label);
}
(async () => {
  const browser = await chromium.launch({
    ...(process.env.CHROME_PATH ? {executablePath: process.env.CHROME_PATH} : {}),
    headless: true,
    args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']
  });
  const report = {date: new Date().toISOString(), browser: browser.version(), renderer: '软件 WebGL，仅功能回归', cases: []};
  try {
    for (const [sample, markers] of cases) {
      const page = await browser.newPage({viewport: {width:1120,height:820}});
      const logs = [], errors = [];
      page.on('console', message => {
        const text = message.text(); logs.push(text);
        if (sample === "navigation-character" && text.includes("HXMAKER_NAV_")) console.log(text);
        if (message.type() === 'error' || /检查失败|断言失败|加载失败|创建失败/.test(text)) errors.push(text);
      });
      page.on('pageerror', error => errors.push(error.stack));
      await page.goto(`${base}/samples/${sample}/Export/html5/bin/`);
      await until(() => errors.length || markers.every(marker => logs.some(log => log.includes(marker))), sample);
      assert.deepEqual(errors, [], sample + ' 不应出现运行异常');
      const entry = {sample, passed: logs.filter(log => markers.some(marker => log.includes(marker)))};
      if (sample === 'navigation-character') {
        const saw = text => logs.some(log => log.includes(text));
        await page.mouse.click(80,76);
        await until(() => saw('HXMAKER_NAV_ACTION 穿门 / 绕墙 moving'), '真实鼠标指定路线');
        await page.keyboard.press('Space');
        await until(() => saw('HXMAKER_NAV_KEY 32 paused'), '键盘暂停');
        await page.keyboard.press('Space');
        await until(() => saw('HXMAKER_NAV_KEY 32 moving'), '键盘恢复');
        const selectionCount = logs.filter(log => log.includes('HXMAKER_NAV_SELECT')).length;
        await page.mouse.move(600,340); await page.mouse.down();
        await page.mouse.move(680,380,{steps:5}); await page.mouse.up();
        assert.equal(logs.filter(log => log.includes('HXMAKER_NAV_SELECT')).length, selectionCount, '左键拖镜头不应误触发选点');
        await page.keyboard.press('Escape');
        await until(() => saw('HXMAKER_NAV_KEY 27 idle'), '键盘停止');
        await page.mouse.click(80,76);
        await page.mouse.click(50,115);
        await until(() => saw('HXMAKER_NAV_ACTION 门：开 moving'), '门开关保留移动');
        await page.screenshot({path: process.env.HXMAKER_TEST_SCREENSHOT || '/tmp/hxmaker-navigation.png'});
        for (let i = 0; i < 2; i++) {
          await page.mouse.click(110,794);
          await until(() => logs.filter(log => log.includes('HXMAKER_NAV_SAMPLE_CHECKS PASS')).length >= i+2, '重新进入场景');
        }
        const releases = logs.filter(log => log.includes('HXMAKER_NAV_RELEASE')).map(log => JSON.parse(log.slice(log.indexOf('{'))));
        assert.equal(releases.length,2);
        for (const release of releases) {
          for (const key of ['worldDisposed','agentDisposed','graphDisposed','controllerDisposed','inputDisposed']) assert.equal(release[key],true,key);
          for (const key of ['colliders','geometryReferences','materialReferences']) assert.equal(release[key],0,key);
        }
        entry.ui = ['鼠标指定目标','键盘暂停恢复停止','左键拖动不误选','行走中关门','两次销毁重进'];
        entry.releases = releases;
      }
      assert.deepEqual(errors, [], sample + ' 后续操作异常');
      report.cases.push(entry);
      console.log(sample + ' PASS');
      await page.close();
    }
    if (process.env.HXMAKER_TEST_REPORT) {
      const output = path.resolve(process.env.HXMAKER_TEST_REPORT);
      fs.mkdirSync(path.dirname(output), {recursive:true});
      fs.writeFileSync(output, JSON.stringify(report,null,2)+'\n');
    }
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
