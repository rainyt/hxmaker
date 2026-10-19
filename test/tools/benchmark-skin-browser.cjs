// 在隔离页面中同步推进动画，排除软件 GPU 的绘制等待；仅在测试响应中注入入口。
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const inject=`
 if(name==='__benchmarkSkin'){
  var agents=this.world.herd.agents;
  for(var warm=0;warm<40;warm++)for(var a of agents)a.model.update(1/60);
  var samples=[];
  for(var step=0;step<120;step++){
   var start=performance.now();for(var a of agents)a.model.update(1/60);samples.push(performance.now()-start);
  }
  for(var a of agents)for(var mesh of a.model.get_meshes()){
   var g=mesh.get_geometry(),lo=[Infinity,Infinity,Infinity],hi=[-Infinity,-Infinity,-Infinity];
   for(var i=0;i<g.positions.length;i++){var value=g.positions[i];if(!Number.isFinite(value))throw Error('蒙皮顶点非有限值');lo[i%3]=Math.min(lo[i%3],value);hi[i%3]=Math.max(hi[i%3],value);}
   var b=g.bounds;if(lo.some((v,i)=>v!==[b.min.x,b.min.y,b.min.z][i])||hi.some((v,i)=>v!==[b.max.x,b.max.y,b.max.z][i]))throw Error('蒙皮融合边界错误');
   if(g.getNormals().some(v=>!Number.isFinite(v)))throw Error('蒙皮法线非有限值');
  }
  window.__skinBenchmark={count:agents.length,samples};return;
 }
`;
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const base=process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733',root=base+'/samples/3d/away3d-explorer/Export/';
  const report={description:'20 个独立动画实例，预热 40 步，测量 120 步；同步循环中不绘制，耗时包含几何变更事件',runs:[]};
  for(const variant of ['before-skin','checks','before-skin','checks']){
   const page=await browser.newPage({viewport:{width:1120,height:760}}),errors=[];page.on('pageerror',e=>errors.push(String(e)));
   await page.route('**/AwayExplorer.js',async route=>{const response=await route.fetch();let body=await response.text();const marker=',checkCommand: function(name,x,z) {';assert(body.includes(marker),'测试入口未找到');body=body.replace(marker,marker+inject);await route.fulfill({response,body});});
   await page.goto(root+variant+'/html5/bin/');await page.waitForFunction(()=>window.__hxmakerExplorer?.state().ready,null,{timeout:60000});
   await page.evaluate(()=>window.__hxmakerExplorer.command('herdMode'));await page.waitForTimeout(1500);
   const result=await page.evaluate(()=>{window.__hxmakerExplorer.command('__benchmarkSkin');return window.__skinBenchmark;});assert.equal(result.count,20);assert.deepEqual(errors,[]);
   const values=result.samples.slice().sort((a,b)=>a-b);const row={variant,count:result.count,meanMs:values.reduce((a,b)=>a+b)/values.length,p50Ms:values[60],p95Ms:values[114],samples:result.samples};report.runs.push(row);console.log(JSON.stringify({...row,samples:undefined}));await page.close();
  }
  if(process.env.HXMAKER_TEST_REPORT)fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
