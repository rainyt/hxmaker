// 阴影几何缓存回归：像素对照、缓冲复用、动态失效、容量边界和设备恢复。
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader',...(process.env.HXMAKER_WEBGL1?['--disable-webgl2']:[])]});
 try{
  const page=await browser.newPage({viewport:{width:960,height:640}}),errors=[],report={cases:[]};
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text());});
  await page.goto(`${process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733'}/test/shadow-cache/Export/html5/bin/`);
  const state=()=>page.evaluate(()=>window.__shadowCache.state());
  await page.waitForFunction(()=>window.__shadowCacheError||window.__shadowCache?.state().ready&&window.__shadowCache.state().stats.shadowDrawCalls>0,null,{timeout:30000});assert.equal(await page.evaluate(()=>window.__shadowCacheError),undefined);
  report.webgl=(await state()).webgl;report.vao=(await state()).stats.stateVao;
  if(process.env.HXMAKER_WEBGL1)assert.match(report.webgl,/WebGL 1/);
  if(process.env.HXMAKER_NO_VAO)assert.equal(report.vao,false);
  const pass=text=>{report.cases.push(text);console.log('PASS '+text);};
  async function command(name){const id=(await state()).stats.redrawId;await page.evaluate(name=>window.__shadowCache.command(name),name);await page.waitForFunction(id=>window.__shadowCache.state().stats.redrawId>id,id,{timeout:30000});const s=await state();assert.equal(s.error,0,name);return s;}
  const pixels=()=>page.evaluate(()=>window.__shadowCache.pixels());
  async function reference(label){await command('refresh');const image=await pixels(),count=(await state()).stats.shadowDrawCalls;await command('reference');assert.deepEqual(await pixels(),image,label+' 缓存与重建像素不同');assert.equal((await state()).stats.shadowDrawCalls,count,label+' 不应增加绘制批次');}
  await command('refresh');assert.equal((await state()).stats.shadowUploadedBytes,0);assert((await state()).stats.shadowGeometryCacheHits>0);await reference('初始场景');pass('阴影几何复用不上传，像素与重建一致，保持合批');
  await command('capture');let s=await command('camera');assert.equal(s.stats.shadowUploadedBytes,0);assert(s.reused>0);await reference('相机移动');pass('相机移动复用 GPU 缓冲和 CPU TypedArray');
  s=await command('light');assert.equal(s.stats.shadowUploadedBytes,0);await reference('光方向变化');pass('仅光照矩阵变化仍复用几何');
  await command('capture');s=await command('move');assert(s.stats.shadowGeometryRebuilds>0&&s.stats.shadowUploadedBytes>0);assert(s.reused>0);assert.equal(s.stats.shadowIndexUploadedBytes,0);await reference('模型移动');pass('动态变换重建且复用已有容量');
  for(const name of ['parent','mirror','geometry','replace']){s=await command(name);assert(s.stats.shadowGeometryRebuilds>0,name);await reference(name);}pass('父级变换、负缩放、顶点修改及几何替换使缓存失效');
  s=await command('color');assert.equal(s.stats.shadowUploadedBytes,0);await reference('颜色变化');pass('不影响投影的颜色变化不重传几何');
  for(const name of ['opacity','cutoff']){s=await command(name);assert(s.stats.shadowDrawCalls>0);assert.equal(s.stats.shadowUploadedBytes,0);await reference(name);}pass('MASK 透明度和阈值更新阴影但复用几何');
  await command('opacity');for(const name of ['atlas','atlasMutate','uv','alpha','maskOff','maskOn','hide','show']){s=await command(name);assert(s.stats.shadowGeometryRebuilds>0,name);await reference(name);}pass('图集 UV、MASK 切换和投射物可见性正确失效');
  s=await command('large');assert(s.stats.shadowTriangles>=22000);await reference('顶点上限');await command('removeLarge');pass('超过 65535 顶点正确拆批');
  s=await command('indices');assert(s.stats.shadowTriangles>=65536);await reference('索引上限');await command('removeLarge');pass('重复索引超过批次容量正确拆批');
  s=await command('auto');assert.equal(s.stats.shadowCascades,2);await reference('两级阴影');s=await command('camera');assert(s.stats.shadowGeometryCacheHits>0);assert.equal(s.stats.shadowUploadedBytes,0);pass('相机取景两级阴影复用各级几何');
  s=await command('dynamic');assert(s.stats.shadowDynamicGeometryRebuilds>0);await reference('切换动态');
  for(const name of ['move','parent','mirror']){s=await command(name);assert.equal(s.stats.shadowUploadedBytes,0,name+' 动态变换不应上传几何');await reference('动态 '+name);}pass('动态物体与父级移动、镜像仅更新矩阵，静态几何不重传');
  for(const name of ['geometry','replace']){s=await command(name);assert(s.stats.shadowDynamicUploadedBytes>0);assert.equal(s.stats.shadowStaticUploadedBytes,0);assert.equal(s.stats.shadowDynamicGeometryRebuilds,1);await reference('动态 '+name);}pass('动态顶点修改仅重建一个对象，两个级联共享上传');
  s=await command('indicesSwap');assert(s.stats.shadowIndexUploadedBytes>0);await reference('动态索引原地修改');s=await command('geometry');assert.equal(s.stats.shadowIndexUploadedBytes,0);pass('阴影顶点更新不上传索引，原地修改索引时正确重传');
  s=await command('dynamicMask');await reference('动态 MASK');
  for(const name of ['opacity','cutoff']){s=await command(name);assert.equal(s.stats.shadowUploadedBytes,0);await reference('动态 MASK '+name);}
  for(const name of ['atlas','atlasMutate','uv']){s=await command(name);assert(s.stats.shadowDynamicUploadedBytes>0);assert.equal(s.stats.shadowStaticUploadedBytes,0);await reference('动态 MASK '+name);}pass('动态 MASK 材质参数、图集和 UV 正确失效');
  s=await command('static');assert(s.stats.shadowStaticUploadedBytes>0);assert.equal(s.stats.shadowDynamicUploadedBytes,0);await reference('切回静态');pass('运行时切换静态／动态策略后阴影正确');
  s=await command('group');assert.equal(s.stats.shadowDynamicGeometryRebuilds,1);await reference('多网格模型');
  await command('capture');for(const name of ['groupMove','groupMirror']){s=await command(name);assert.equal(s.stats.shadowUploadedBytes,0);assert(s.reused>0);await reference(name);}
  for(const name of ['groupChild','groupVertex']){s=await command(name);assert.equal(s.stats.shadowStaticUploadedBytes,0);assert.equal(s.stats.shadowDynamicGeometryRebuilds,1);assert(s.stats.shadowDynamicUploadedBytes>0);await reference(name);}
  const dynamicImage=await pixels();await command('groupStatic');const staticImage=await pixels();let different=0;for(let i=0;i<dynamicImage.length;i++)if(Math.abs(dynamicImage[i]-staticImage[i])>3)different++;assert(different<dynamicImage.length*.001,'模型局部空间投影与世界空间投影不一致：'+different);await command('groupDynamic');await reference('模型切回动态');pass('多网格模型共享缓存，根变换零上传，子变换与顶点正确失效，投影与静态路径一致');
  s=await command('disable');assert.equal(s.stats.shadowGeometryBytes,0);s=await command('enable');assert(s.stats.shadowGeometryRebuilds>0);pass('关闭阴影释放几何，重新开启重建');
  const image=await pixels();await page.evaluate(()=>window.__shadowCache.command('lose'));await page.waitForFunction(()=>window.__shadowCache.state().error===-1);await page.waitForFunction(()=>window.__shadowCache.state().error===0&&window.__shadowCache.state().stats.shadowGeometryBytes>0,null,{timeout:30000});assert.deepEqual(await pixels(),image);pass('上下文恢复重新创建几何，阴影像素一致');
  await page.evaluate(()=>window.__shadowCache.command('dispose'));assert.equal((await state()).disposedBytes,0);assert.equal((await state()).disposedHandles,0);pass('场景销毁释放所有阴影几何缓存');
  assert.deepEqual(errors,[]);if(process.env.HXMAKER_TEST_REPORT)fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');
  console.log('HXMAKER_SHADOW_CACHE PASS '+report.cases.length);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
