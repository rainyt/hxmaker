// 同一页面对比编译前后；硬件与软件结果分开记录，不把提交计时当作 GPU 耗时。
const fs = require('node:fs');
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/usr/local/lib/node_modules/playwright');
const hardware = process.env.HXMAKER_GPU === 'hardware';
const pixelRatio = Number(process.env.HXMAKER_DPR || 1);
const variants = (process.env.HXMAKER_VARIANTS || 'before,after').split(',');
const injection = `
 if(name==='__deepPose'){
  this.world.herd.mode=1;this.world.herd.root.set_visible(true);
  this.world.controller.teleport(new hx_geom_Vector3D(0,.05,27));this.world.yaw=0;this.world.pitch=-.02;this.world.updateCamera();
  for(var i=0;i<this.world.herd.agents.length;i++){
   var a=this.world.herd.agents[i];a.model.set_x(-20+(i%10)*4);a.model.set_z(10+Math.floor(i/10)*7);a.model.set_rotationY(i*19);
   a.model.animation.seek(.5+i*.097);
  }
  return;
 }
 if(name==='__deepCpu'){
  var agents=this.world.herd.agents,samples=[];
  for(var warm=0;warm<40;warm++)for(var a of agents)a.model.update(1/60);
  for(var step=0;step<180;step++){var start=performance.now();for(var a of agents)a.model.update(1/60);samples.push(performance.now()-start);}
  window.__deepCpu=samples;return;
 }
`;
const mean = values => values.reduce((a, b) => a + b, 0) / values.length;
const quantile = (values, q) => values.slice().sort((a, b) => a - b)[Math.min(values.length - 1, Math.floor(values.length * q))];
(async () => {
 const browser = await chromium.launch({headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', args: hardware ? ['--enable-webgl', '--use-angle=metal'] : ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']});
 const report = { backend: hardware ? '请求硬件 ANGLE Metal，以实际 renderer 为准' : 'SwiftShader 软件 WebGL', viewport: [1120, 760], pixelRatio, browser: browser.version(), runs: [] };
 try {
  for (const variant of variants) {
   const page = await browser.newPage({viewport: {width: 1120, height: 760}, deviceScaleFactor: pixelRatio}), errors = [];
   page.on('pageerror', e => errors.push(String(e)));
   await page.addInitScript(()=>{const original=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(...args){const g=original.apply(this,args);if(g&&args[0].startsWith('webgl'))window.__profileGL=g;return g;};});
   await page.route('**/AwayExplorer.js', async route => {
    const response = await route.fetch();
    const body = variant === 'before' ? fs.readFileSync(process.env.HXMAKER_BEFORE_JS || '/tmp/hxmaker-deep-before.js', 'utf8') : await response.text();
    const marker = ',checkCommand: function(name,x,z) {';
    assert(body.includes(marker), '需要 hxmaker_explorer_checks 构建');
    await route.fulfill({response, body: body.replace(marker, marker + injection)});
   });
   await page.goto(process.env.HXMAKER_EXPLORER_URL || 'http://127.0.0.1:8733/samples/3d/away3d-explorer/Export/html5/bin/');
   await page.waitForFunction(() => window.__hxmakerExplorer?.state().ready, null, {timeout: 60000});
   const command = name => page.evaluate(name => window.__hxmakerExplorer.command(name), name);
   const renderer = await page.evaluate(() => {const g=window.__profileGL; const e = g.getExtension('WEBGL_debug_renderer_info'); const s=window.__hxmakerExplorer.state().stats;return {version: g.getParameter(g.VERSION), renderer: e ? g.getParameter(e.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER), target:[s.targetWidth,s.targetHeight]};});
   const run = {variant, renderer, scenarios: []};
   for (const [name, mode, animation, shadows] of [['hidden',2,false,false],['frozen',1,true,true],['rigid_shadow',0,false,true],['animated_shadow',0,true,true]]) {
    await page.evaluate(([mode, animation, shadows]) => {const api=window.__hxmakerExplorer;while(api.state().dinosaurs.mode!==mode)api.command('herdMode');if(api.state().dinosaurs.animation!==animation)api.command('herdAnimation');if(api.state().dinosaurs.shadows!==shadows)api.command('herdShadows');}, [mode, animation, shadows]);
    await page.waitForTimeout(1800);
    const rows = await page.evaluate(() => new Promise(resolve => {const rows=[],start=performance.now();let previous=start;function tick(now){const s=window.__hxmakerExplorer.state().stats;rows.push({frame:now-previous,cpu:s.renderCpuMs,main:s.mainCpuMs,shadow:s.shadowCpuMs,upload:s.redrawThisFrame?s.uploadedBytes:0,shadowUpload:s.redrawThisFrame?s.shadowUploadedBytes:0,draws:s.redrawThisFrame?s.drawCalls:0,palette:s.redrawThisFrame?(s.skinPaletteUploadedBytes||0):0,gpuMeshes:s.gpuSkinMeshes||0});previous=now;if(now-start>=3000)resolve(rows);else requestAnimationFrame(tick);}requestAnimationFrame(tick);}));
    const result={name,frames:rows.length,p50FrameMs:quantile(rows.map(r=>r.frame),.5),p95FrameMs:quantile(rows.map(r=>r.frame),.95),renderCpuMs:mean(rows.map(r=>r.cpu)),mainCpuMs:mean(rows.map(r=>r.main)),shadowCpuMs:mean(rows.map(r=>r.shadow)),uploadedBytes:mean(rows.map(r=>r.upload)),shadowUploadedBytes:mean(rows.map(r=>r.shadowUpload)),drawCalls:mean(rows.map(r=>r.draws)),skinPaletteUploadedBytes:mean(rows.map(r=>r.palette)),gpuSkinMeshes:mean(rows.map(r=>r.gpuMeshes))};
    run.scenarios.push(result);console.log(variant+' '+JSON.stringify(result));
   }
   await command('__deepPose');await page.waitForTimeout(1500);
   await page.screenshot({path:'/tmp/hxmaker-deep-'+variant+(hardware?'-hardware':'-software')+'-dpr'+pixelRatio+'.png'});
   await command('__deepCpu');const samples=await page.evaluate(()=>window.__deepCpu);run.animation={meanMs:mean(samples),p50Ms:quantile(samples,.5),p95Ms:quantile(samples,.95)};
   assert.deepEqual(errors, []);report.runs.push(run);await page.close();
  }
  fs.writeFileSync(process.env.HXMAKER_TEST_REPORT || '/tmp/hxmaker-deep-profile.json', JSON.stringify(report,null,2)+'\n');
 } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
