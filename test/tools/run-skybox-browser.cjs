// 天空功能回归；先构建带 hxmaker_skybox_checks 的示例并启动本地静态服务。
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.HXMAKER_TEST_BASE || 'http://127.0.0.1:8732';
(async () => {
  const browser = await chromium.launch({headless:true,
    ...(process.env.CHROME_PATH ? {executablePath:process.env.CHROME_PATH} : {}),
    args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader',
      ...(process.env.HXMAKER_WEBGL1 ? ['--disable-webgl2'] : [])]});
  const report = {browser:browser.version(), backend:'软件 WebGL，仅验证功能', cases:[]};
  try {
    const page = await browser.newPage({viewport:{width:1000,height:700}}), errors = [], logs = [];
    page.on('console', message => { logs.push(message.text()); if (message.type() === 'error' && !message.text().includes('favicon')) errors.push(message.text()); });
    page.on('pageerror', error => errors.push(error.stack));
    await page.goto(`${base}/samples/3d/skybox/Export/html5/bin/`);
    await page.waitForFunction(() => window.__hxmakerSkybox?.state().side.skyboxDrawCalls === 1, null, {timeout:20000});
    const state = () => page.evaluate(() => window.__hxmakerSkybox.state());
    const pixel = (x=.5,y=.5,main=false) => page.evaluate(([x,y,main]) => window.__hxmakerSkybox.pixel(x,y,main),[x,y,main]);
    const distance = (a,b) => Math.max(...a.map((v,i) => Math.abs(v-b[i])));
    async function command(name, view='side') {
      const previous = (await state())[view].redrawId;
      await page.evaluate(name => window.__hxmakerSkybox.command(name), name);
      await page.waitForFunction(([view,previous]) => window.__hxmakerSkybox.state()[view].redrawId > previous,[view,previous]);
      assert.equal((await state()).glError,0,name+' GL 状态');
    }
    const pass = message => {report.cases.push(message); console.log('PASS '+message);};
    assert(logs.some(log=>log.includes('HXMAKER_SKYBOX_CORE PASS')));
    let initial = await state();
    report.webgl = initial.webglVersion; report.vao = initial.side.stateVao;
    if (process.env.HXMAKER_WEBGL1) assert.match(initial.webglVersion,/WebGL 1/);
    if (process.env.HXMAKER_NO_VAO) assert.equal(initial.side.stateVao,false);
    assert.equal(initial.side.drawCalls,0); assert.equal(initial.side.environmentStatus,'无 PBR 材质');
    assert.equal(initial.main.drawCalls,2); assert.equal(initial.main.skyboxDrawCalls,1);
    pass('核心接口、空场景天空、独立批次');
    await page.waitForTimeout(300); initial = await state();
    await page.waitForTimeout(300); assert.equal((await state()).side.redrawId, initial.side.redrawId);
    pass('关闭自动重绘时复用离屏结果');
    const original = await pixel();
    const originalGrid = []; for (const y of [.1,.5,.9]) for (const x of [.1,.5,.9]) originalGrid.push(await pixel(x,y));
    await command('translate'); assert(distance(original,await pixel())<=1);
    await command('clip'); assert(distance(original,await pixel())<=1);
    pass('相机平移和近远裁剪不改变天空');
    await command('rotate');
    const rotatedGrid = []; for (const y of [.1,.5,.9]) for (const x of [.1,.5,.9]) rotatedGrid.push(await pixel(x,y));
    assert(originalGrid.some((value,index)=>distance(value,rotatedGrid[index])>4),'旋转应改变天空中具有方向性的亮部');
    await command('exposure'); const exposed = await pixel(); assert(exposed[0]>original[0]);
    await command('disable'); assert.deepEqual(await pixel(),[23,32,51,255]);
    await command('enable'); assert(distance(exposed,await pixel())<=1);
    await command('noCamera'); assert.equal((await state()).side.skyboxStatus,'无相机');
    await command('restoreCamera');
    pass('旋转、曝光、开关和缺少相机回退');
    const beforeShared = await state(); await command('invalidate');
    await page.waitForFunction(previous => window.__hxmakerSkybox.state().main.redrawId > previous,beforeShared.main.redrawId);
    assert.equal((await state()).rotation,0); assert.equal((await state()).sideRotation,0);
    pass('共享资源失效传播，场景参数隔离');
    await command('original'); await command('fixture');
    const narrow = await pixel(.9,.5); await command('fov'); assert(distance(narrow,await pixel(.9,.5))>5,'天空视野应匹配相机 FOV');
    const axes = [['fixture',[255,128,128]],['negativeX',[0,128,128]],['positiveZ',[128,128,255]],
      ['negativeZ',[128,128,0]],['positiveY',[128,255,128]],['negativeY',[128,0,128]]];
    for (const [name,expected] of axes) {
      if (name!=='fixture') await command(name);
      const actual = await pixel(); assert(distance(actual.slice(0,3),expected)<=17,`${name}：${actual}`); assert.equal(actual[3],255);
    }
    await command('seamLeft'); const left = await pixel(); await command('seamRight'); assert(distance(left,await pixel())<=2);
    pass('非二次幂普通全景的六向采样、极点和周期接缝');
    await command('original'); await command('ibl'); assert.equal((await state()).side.skyboxDrawCalls,1);
    assert.equal((await pixel())[3],255);
    pass('旧 IBL 图集第零层背景复用');
    await command('original');
    const model = await pixel(.41,.5,true), glass = await pixel(.59,.5,true);
    await command('mainDisable','main');
    const modelWithoutSky = await pixel(.41,.5,true), glassWithoutSky = await pixel(.59,.5,true);
    assert(distance(model,modelWithoutSky)<=1,'不透明模型遮挡天空');
    assert(distance(glass,glassWithoutSky)>3,'透明模型与天空混合');
    await command('mainEnable','main');
    await command('bloom','main'); assert.equal((await state()).main.bloomStatus,'启用');
    pass('不透明遮挡、透明合成和 Bloom 接入');
    await page.screenshot({path:process.env.HXMAKER_TEST_SCREENSHOT || '/tmp/hxmaker-skybox.png'});
    await command('lowPrecision'); assert.equal((await state()).side.skyboxStatus,'启用');
    await command('bright'); assert.match((await state()).side.skyboxStatus,/片元精度/);
    assert.deepEqual(await pixel(),[23,32,51,255]);
    await command('fullPrecision'); assert.equal((await state()).side.skyboxStatus,'启用');
    await command('limitSize'); assert.match((await state()).side.skyboxStatus,/纹理尺寸/);
    assert.deepEqual(await pixel(),[23,32,51,255]);
    await command('restoreSize'); assert.equal((await state()).side.skyboxStatus,'启用');
    pass('低精度着色器及亮度、尺寸超限回退恢复');
    const before = await pixel();
    await page.evaluate(()=>window.__hxmakerSkybox.command('loseContext'));
    await page.waitForFunction(()=>window.__hxmakerSkybox.state().glError===-1);
    await page.waitForFunction(()=>window.__hxmakerSkybox.state().glError===0 && window.__hxmakerSkybox.pixel().length===4,null,{timeout:20000});
    assert(distance(before,await pixel())<=2);
    pass('上下文丢失后天空纹理、程序与目标恢复');
    await page.screenshot({path:'/tmp/hxmaker-skybox-restored.png'});
    await command('detachPrimary','main');
    assert.equal((await state()).main.skyboxDrawCalls,0); assert.equal((await state()).side.skyboxDrawCalls,1);
    assert(distance(before,await pixel())<=2);
    pass('解除主场景配置不影响共享天空的第二场景');
    assert.deepEqual(errors,[]);
    if (process.env.HXMAKER_TEST_REPORT) fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');
    console.log('HXMAKER_SKYBOX_BROWSER PASS '+report.cases.length);
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
