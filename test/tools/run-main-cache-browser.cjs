// 主场景持久几何与 AUTO 回归；软件 WebGL 只验证正确性和上传行为。
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader',...(process.env.HXMAKER_WEBGL1?['--disable-webgl2']:[])]});
 try{
  const page=await browser.newPage({viewport:{width:960,height:640}}),errors=[],report={cases:[],pixelComparisons:[]};
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text());});
  await page.goto(`${process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733'}/test/shadow-cache/Export/html5/bin/`);
  const state=()=>page.evaluate(()=>window.__shadowCache.state());
  await page.waitForFunction(()=>window.__shadowCacheError||window.__shadowCache?.state().ready&&window.__shadowCache.state().stats.drawCalls>0,null,{timeout:30000});assert.equal(await page.evaluate(()=>window.__shadowCacheError),undefined);
  report.webgl=(await state()).webgl;report.vao=(await state()).stats.stateVao;
  if(process.env.HXMAKER_WEBGL1)assert.match(report.webgl,/WebGL 1/);if(process.env.HXMAKER_NO_VAO)assert.equal(report.vao,false);
  async function command(name){const id=(await state()).stats.redrawId;await page.evaluate(name=>{try{window.__shadowCache.command(name)}catch(e){throw new Error(e.value||e.message||String(e))}},name);await page.waitForFunction(id=>window.__shadowCache.state().stats.redrawId>id,id,{timeout:30000});const s=await state();assert.equal(s.error,0,name);return s;}
  const pixels=()=>page.evaluate(()=>window.__shadowCache.pixels());
  const pass=text=>{report.cases.push(text);console.log('PASS '+text);};
  async function reference(label){await command('refresh');const image=await pixels();await command('referenceMain');assert.deepEqual(await pixels(),image,label+' 强制重建应与缓存一致');await command('geometryCacheOff');const legacy=await pixels();let different=0,max=0;for(let i=0;i<image.length;i++){let delta=Math.abs(image[i]-legacy[i]);max=Math.max(max,delta);if(delta>4)different++;}report.pixelComparisons.push({label,different,max,total:image.length});assert(different<image.length*.002,label+' 与原路径像素差异过多：'+different);await command('geometryCacheOn');}
  await command('skinCheck');assert.equal((await state()).skinChecks,true);pass('双关节蒙皮顶点、法线、融合边界和变更事件正确，公开校验保留');
  await command('geometryStatic');let s=await command('refresh');assert.equal(s.stats.uploadedBytes,0);assert(s.stats.geometryCacheHits>0);await reference('静态环境');pass('静态环境复用顶点与索引，像素与原绘制路径一致');
  await command('captureMain');for(const name of ['camera','light']){await command('captureMain');s=await command(name);assert.equal(s.stats.uploadedBytes,0);assert(s.mainReused>0);await reference(name);}pass('相机和灯光变化零几何上传');
  await command('captureMain');s=await command('move');assert(s.stats.geometryStaticUploadedBytes>0);assert.equal(s.stats.geometryIndexUploadedBytes,0);assert(s.mainReused>0);await reference('静态物体修改');pass('静态物体修改只更新相关顶点，复用缓冲容量与索引');
  await command('geometryDynamic');await command('captureMain');for(const name of ['move','parent','mirror']){await command('captureMain');s=await command(name);assert.equal(s.stats.uploadedBytes,0);assert(s.mainReused>0);await reference('动态 '+name);}pass('动态及父级平移、旋转和负缩放仅更新矩阵');
  for(const name of ['color','geometry','uv','atlas','atlasMutate','alpha']){s=await command(name);assert(s.stats.uploadedBytes>0,name);assert.equal(s.stats.geometryIndexUploadedBytes,0,name);await reference(name);}pass('颜色、顶点、UV、图集和顶点透明度更新正确，索引不重传');
  s=await command('replace');assert(s.stats.geometryIndexUploadedBytes>0);await reference('替换几何');s=await command('indicesSwap');assert(s.stats.geometryIndexUploadedBytes>0);await reference('原地修改索引');pass('几何替换与原地修改索引均正确更新 GPU 索引');
  await command('autoPolicy');await page.waitForFunction(()=>window.__shadowCache.state().autoStatic&&window.__shadowCache.state().autoShadowStatic);s=await command('refresh');assert.equal(s.stats.uploadedBytes,0);assert.equal(s.stats.shadowUploadedBytes,0);pass('AUTO 在无自动重绘的静止场景中也会转静态');
  for(const name of ['camera','light']){await command(name);assert((await state()).autoStatic);}await command('colorToggle');assert((await state()).autoStatic);pass('相机、灯光和材质颜色不影响 AUTO 静止判定');
  s=await command('move');assert.equal(s.autoStatic,false);assert.equal(s.autoShadowStatic,false);assert.equal(s.stats.uploadedBytes,0);await page.waitForFunction(()=>window.__shadowCache.state().autoStatic);pass('AUTO 当帧转动态，持续静止后转静态且不搬迁环境缓存');
  await command('parent');assert.equal((await state()).autoStatic,false);await page.waitForFunction(()=>window.__shadowCache.state().autoStatic);await command('geometry');assert.equal((await state()).autoStatic,false);await page.waitForFunction(()=>window.__shadowCache.state().autoStatic);pass('父级移动与程序顶点修改均能激活 AUTO');
  await command('autoZero');assert.equal(await page.evaluate(()=>{window.__shadowCache.command('moveAndSync');return window.__shadowCache.state().autoStatic;}),false);await page.waitForFunction(()=>window.__shadowCache.state().autoStatic);pass('零等待时间仍保持移动当帧动态，后续更新才允许静态');
  await command('autoPolicy');
  await command('group');await command('autoGroup');await command('groupScale');await reference('模型非均匀及负缩放');await command('groupMove');s=await command('refresh');assert.equal(s.stats.uploadedBytes,0);await reference('多网格模型移动');pass('多网格模型局部缓存与法线变换正确');
  await command('groupPlay');await page.waitForTimeout(400);s=await state();assert.equal(s.groupAutoStatic,false);assert(s.stats.geometryDynamicUploadedBytes>0);assert.equal(s.stats.geometryIndexUploadedBytes,0);await command('groupFreeze');await page.waitForFunction(()=>window.__shadowCache.state().groupAutoStatic);s=await command('refresh');assert.equal(s.stats.uploadedBytes,0);pass('动画推进保持动态，停止驱动后即使 playing 为真也可静态');
  await command('groupPlay');await command('groupSpeedZero');await page.waitForFunction(()=>window.__shadowCache.state().groupAutoStatic);await command('groupFreeze');pass('动画速度为零时能自动静态');
  s=await command('pbrGroup');assert.equal(s.pbrGroupBatches,1);await reference('PBR 基础色和粗糙度跨材质合批');pass('同一模型不同线性基础色与粗糙度合为一个缓存批次，颜色空间与旧路径一致');
  for(const name of ['pbrFactor','pbrRoughness']){s=await command(name);assert.equal(s.pbrGroupBatches,1);assert(s.stats.geometryDynamicUploadedBytes>0||s.stats.geometryStaticUploadedBytes>0);assert.equal(s.stats.geometryIndexUploadedBytes,0);await reference(name);}pass('PBR 顶点参数修改只更新顶点，仍保持合批且索引不上传');
  s=await command('pbrMetallic');assert.equal(s.pbrGroupBatches,2);await reference('PBR 金属度分组');await command('pbrGroup');s=await command('pbrEmission');assert.equal(s.pbrGroupBatches,2);await reference('PBR 自发光分组');pass('金属度、自发光等共享 uniform 差异仍正确拆批');
  for(const name of ['hide','show']){await command(name);await reference(name);}pass('投射物和可见性变化正确更新缓存成员');
  await command('pbrMapped');await reference('PBR 法线贴图');pass('PBR 法线贴图在非均匀及负缩放下与原路径一致');
  await command('transparent');await reference('透明排序');await command('maskOn');pass('透明材质沿用原有排序，缓冲复用不改变画面');
  await command('groupFarPart');s=await command('groupShift');assert.equal(s.stats.uploadedBytes,0);assert.equal(s.stats.geometryIndexUploadedBytes,0);await reference('模型不同材质部分陆续入镜');pass('可见模型预备全部材质组，刚体运动中不同部件入镜不重传');
  const image=await pixels();await page.evaluate(()=>window.__shadowCache.command('lose'));await page.waitForFunction(()=>window.__shadowCache.state().error===-1);await page.waitForFunction(()=>window.__shadowCache.state().error===0&&window.__shadowCache.state().stats.geometryCacheBytes>0,null,{timeout:30000});assert.deepEqual(await pixels(),image);pass('设备恢复重建主场景缓冲，像素一致');
  await page.evaluate(()=>window.__shadowCache.command('dispose'));s=await state();assert.equal(s.disposedMainBytes,0);assert.equal(s.disposedMainHandles,0);pass('销毁释放主场景 GPU 缓冲与 CPU 容量');
  assert.deepEqual(errors,[]);if(process.env.HXMAKER_TEST_REPORT)fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');console.log('HXMAKER_MAIN_CACHE PASS '+report.cases.length);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
