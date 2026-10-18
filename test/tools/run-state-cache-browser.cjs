// 先编译 GLStateCacheChecks.hx，再通过真实 WebGL 对照状态缓存与驱动结果。
const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try {
  for(const mode of ['webgl2','webgl1']) {
   const page=await browser.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));
   await page.goto(`${process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733'}/test/?${mode}`);
   await page.addScriptTag({path:process.env.HXMAKER_STATE_CHECKS_JS||'/tmp/hxmaker-state-cache-checks.js'});
   assert.deepEqual(errors,[]);assert.equal(await page.evaluate(()=>window.__stateCacheError),undefined);const result=await page.evaluate(()=>window.__stateCacheChecks);
   assert(result?.passed>100);assert.match(result.webgl,mode==='webgl1'?/WebGL 1/:/WebGL 2/);
   console.log(`PASS ${mode} ${result.passed} 次真实状态对照`);await page.close();
  }
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
