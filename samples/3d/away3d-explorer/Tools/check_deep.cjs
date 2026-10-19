// 测试钩子仅注入带验收宏的编译响应，不进入普通构建。
const fs = require('node:fs');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/usr/local/lib/node_modules/playwright');
const injection = `
 if(name==='__deepInstall'){
  var stage=this,world=this.world;
  window.__deep={
   pose:function(time){
    world.herd.mode=1;world.herd.root.set_visible(true);
    world.controller.teleport(new hx_geom_Vector3D(0,.05,27));world.yaw=0;world.pitch=-.02;world.updateCamera();
    for(var i=0;i<world.herd.agents.length;i++){
     var model=world.herd.agents[i].model;model.set_x(-20+(i%10)*4);model.set_z(10+Math.floor(i/10)*7);model.set_rotationY(i*19);
     model.animation.seek(time+i*.097);
    }
    stage.updateHerdLabels();
   },
   gpu:function(enabled){for(var a of world.herd.agents)for(var m of a.model.get_meshes())if(m.skinBinding)m.skinBinding.requested=enabled;world.view.requestRender();},
   data:function(){return world.herd.agents[0].model.get_meshes().map(function(m){return {positions:m.get_geometry().positions.slice(),normals:m.get_geometry().getNormals().slice()};});},
   mutate:function(){var m=world.herd.agents[0].model.get_meshes().find(m=>m.skinBinding&&m.skinBinding.gpuEnabled),g=m.get_geometry();g.uvs[0]+=.125;g.invalidate();},
   writeNormals:function(){
    var meshes=world.herd.agents[0].model.get_meshes().filter(m=>m.skinBinding&&m.skinBinding.gpuEnabled),g=meshes[0].get_geometry(),h=meshes[1].get_geometry();
    var normals=Array.from({length:g.positions.length},(_,i)=>i%3===1?1:0),tangents=Array.from({length:h.positions.length/3*4},(_,i)=>i%4===0||i%4===3?1:0);
    g.setNormals(normals);h.setTangents(tangents);
    return g.getNormals().every((v,i)=>v===normals[i])&&h.getTangents().every((v,i)=>v===tangents[i]);
   },
   mirror:function(){var m=world.herd.agents[0].model;m.setScale(-.8,.6,.9);},
   refresh:function(){world.view.requestRender();},
   shadows:function(enabled){world.view.get_light().shadowEnabled=enabled;world.view.requestRender();},
   captureResources:function(){
    var r=hx_core_Hxmaker.get_engine().renderer.__scene3DDisplays.h[world.view.__id__].renderer3D,buffers=[],programs=[];
    for(var entry of Object.values(r.mainGeometry.entries.h))if(entry&&entry.buffer)for(var key of ['vertexBuffer','indexBuffer','attributeBuffer','skinBuffer'])if(entry.buffer[key])buffers.push(entry.buffer[key]);
    for(var cache of Object.values(r.shadowPass.dynamicGeometry.h))if(cache&&cache.batches)for(var batch of cache.batches)for(var key of ['vertices','indices'])if(batch[key])buffers.push(batch[key]);
    for(var info of Object.values(r.programs.h))if(info&&info.program)programs.push(info.program);
    for(var info of Object.values(r.shadowPass.skinPrograms.h))if(info&&info.program)programs.push(info.program);
    window.__deepResources={gl:r.gl,buffers:buffers,programs:programs};return buffers.length;
   }

  };return;
 }
`;
const pixelCompare = (a,b) => JSON.parse(execFileSync('python3',['-c',
 "from PIL import Image;import sys,json;a=Image.open(sys.argv[1]).convert('RGB').crop((210,145,720,670));b=Image.open(sys.argv[2]).convert('RGB').crop((210,145,720,670));d=[abs(x-y) for p,q in zip(a.getdata(),b.getdata()) for x,y in zip(p,q)];print(json.dumps({'mean':sum(d)/len(d),'largeFraction':sum(x>8 for x in d)/len(d),'max':max(d)}))",a,b],{encoding:'utf8'}));
(async()=>{
 const report={backend:'SwiftShader 软件 WebGL，仅验证正确性',cases:[],pixels:[]};
 const variants=(process.env.HXMAKER_CHECK_VARIANTS||'gpu,webgl1,fallback,attributes,shader').split(',');
 for(const variant of variants){
  const browser=await chromium.launch({headless:true,executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader',...(variant==='webgl1'?['--disable-webgl2']:[])]});
  try{
   const page=await browser.newPage({viewport:{width:1120,height:760}}),errors=[];
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('favicon'))errors.push(m.text());});
   await page.addInitScript(variant=>{
    const original=HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext=function(...args){
     const g=original.apply(this,args);
     if(g&&args[0].startsWith('webgl')&&!g.__deepWrapped){
      g.__deepWrapped=true;window.__deepGL=g;
      const extension=g.getExtension.bind(g),parameter=g.getParameter.bind(g);
      if(variant==='webgl1')g.getExtension=name=>name==='OES_vertex_array_object'?null:extension(name);
      if(variant==='fallback'||variant==='attributes')g.getParameter=name=>variant==='fallback'&&name===g.MAX_VERTEX_UNIFORM_VECTORS?64:variant==='attributes'&&name===g.MAX_VERTEX_ATTRIBS?7:parameter(name);
      if(variant==='shader'){
       const status=g.getShaderParameter.bind(g),log=g.getShaderInfoLog.bind(g);
       g.getShaderParameter=(shader,name)=>name===g.COMPILE_STATUS&&g.getShaderSource(shader).includes('uniform mat4 uSkin[')?false:status(shader,name);
       g.getShaderInfoLog=shader=>g.getShaderSource(shader).includes('uniform mat4 uSkin[')?'测试：模拟设备拒绝骨骼着色器':log(shader);
      }
     }
     return g;
    };
   },variant);
   await page.route('**/AwayExplorer.js',async route=>{const response=await route.fetch(),body=await response.text(),marker=',checkCommand: function(name,x,z) {';assert(body.includes(marker));await route.fulfill({response,body:body.replace(marker,marker+injection)});});
   await page.goto('http://127.0.0.1:8733/samples/3d/away3d-explorer/Export/html5/bin/');
   await page.waitForFunction(()=>window.__hxmakerExplorer?.state().ready,null,{timeout:60000});
   await page.evaluate(()=>window.__hxmakerExplorer.command('__deepInstall'));
   if(process.env.HXMAKER_NO_SHADOW)await page.evaluate(()=>window.__deep.shadows(false));
   const state=()=>page.evaluate(()=>window.__hxmakerExplorer.state());
   // 自动阴影范围带缩小延迟；主动重绘使两次取样都达到同一个稳定范围。
   const settle=async()=>{for(let i=0;i<5;i++){await page.waitForTimeout(250);await page.evaluate(()=>window.__deep.refresh());}await page.waitForTimeout(250);};
   const pass=text=>{report.cases.push(variant+'：'+text);console.log('PASS '+variant+' '+text);};
   await page.waitForTimeout(1000);assert.equal((await state()).dinosaurs.count,20);
   const supported=variant==='gpu'||variant==='webgl1',initialGpuCount=(await state()).stats.gpuSkinMeshes;assert.equal(initialGpuCount>0,supported);
   if(variant==='webgl1'){assert.match(await page.evaluate(()=>window.__deepGL.getParameter(window.__deepGL.VERSION)),/WebGL 1/);assert.equal((await state()).stats.stateVao,false);}
   assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);
   pass(supported?'GPU 蒙皮已启用':variant==='fallback'?'uniform 容量不足时自动回退 CPU':variant==='attributes'?'顶点属性不足时自动回退 CPU':'骨骼着色器编译失败时自动回退 CPU');
   await page.evaluate(()=>window.__deep.pose(.7));await settle();
   const gpuImage='/tmp/hxmaker-deep-check-'+variant+'-gpu.png';await page.screenshot({path:gpuImage});
   const gpuData=await page.evaluate(()=>window.__deep.data());
   await page.evaluate(()=>window.__deep.gpu(false));await page.waitForTimeout(300);
   await page.evaluate(()=>window.__deep.pose(.71));await page.evaluate(()=>window.__deep.pose(.7));await settle();
   const cpuData=await page.evaluate(()=>window.__deep.data());
   for(let m=0;m<gpuData.length;m++)for(const key of ['positions','normals']){assert.equal(gpuData[m][key].length,cpuData[m][key].length);for(let i=0;i<gpuData[m][key].length;i++)assert(Math.abs(gpuData[m][key][i]-cpuData[m][key][i])<1e-7,key+' 精确数据不一致');}
   const cpuImage='/tmp/hxmaker-deep-check-'+variant+'-cpu.png';await page.screenshot({path:cpuImage});
   assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);
   const pixels=pixelCompare(gpuImage,cpuImage);report.pixels.push({variant,...pixels});assert(pixels.mean<1.2&&pixels.largeFraction<.015,JSON.stringify(pixels));
   pass(process.env.HXMAKER_NO_SHADOW?'CPU 顶点、法线与无阴影画面一致':'CPU 顶点与法线一致，主场景和阴影画面一致');
   await page.evaluate(()=>{window.__deep.gpu(true);window.__deep.mirror();window.__deep.pose(1.1);});await page.waitForTimeout(500);
   assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);
   const mirrorGpu='/tmp/hxmaker-deep-check-'+variant+'-mirror-gpu.png';await page.screenshot({path:mirrorGpu});
   await page.evaluate(()=>window.__deep.gpu(false));await page.waitForTimeout(250);
   await page.evaluate(()=>{window.__deep.pose(1.11);window.__deep.pose(1.1);});await settle();
   const mirrorCpu='/tmp/hxmaker-deep-check-'+variant+'-mirror-cpu.png';await page.screenshot({path:mirrorCpu});
   const mirrored=pixelCompare(mirrorGpu,mirrorCpu);report.pixels.push({variant,kind:'非均匀模型镜像',...mirrored});assert(mirrored.mean<1.2&&mirrored.largeFraction<.015,JSON.stringify(mirrored));
   assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);pass('负缩放与非均匀模型缩放画面一致');
   await page.evaluate(()=>window.__deep.gpu(true));await page.waitForTimeout(300);
   if(supported){
    await page.evaluate(()=>window.__deep.pose(1.2));assert(await page.evaluate(()=>window.__deep.writeNormals()));await page.waitForTimeout(300);assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);pass('手动设置法线与切线保持写入值并回退 CPU');
    await page.evaluate(()=>window.__deep.mutate());await page.waitForTimeout(500);assert((await state()).stats.gpuSkinMeshes<initialGpuCount);assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);pass('通用几何修改使相应网格回退 CPU');
   }
   assert(await page.evaluate(()=>window.__deep.captureResources())>20);
   await page.evaluate(()=>{window.__hxmakerExplorer.command('restart');});await page.waitForFunction(()=>window.__hxmakerExplorer.state().ready,null,{timeout:60000});
   assert.equal((await state()).lastRelease.nodes,0);assert((await state()).lastRelease.sceneDisposed);pass('销毁重进释放场景与节点');
   const released=await page.evaluate(()=>{const r=window.__deepResources;return {buffers:r.buffers.filter(b=>r.gl.isBuffer(b)).length,programs:r.programs.filter(p=>r.gl.isProgram(p)).length};});assert.deepEqual(released,{buffers:0,programs:0});pass('销毁释放动态、不变及骨骼属性缓冲和程序');
   if(supported){
    await page.waitForTimeout(700);const old=(await state()).stats.redrawId;
    const available=await page.evaluate(()=>{const g=window.__deepGL,e=g.getExtension('WEBGL_lose_context');if(!e)return false;e.loseContext();setTimeout(()=>e.restoreContext(),250);return true;});assert(available);
    await page.waitForFunction(old=>window.__hxmakerExplorer.state().stats.redrawId>old+2,old,{timeout:45000});
    assert((await state()).stats.gpuSkinMeshes>0);assert.equal(await page.evaluate(()=>window.__deepGL.getError()),0);pass('上下文恢复后重建几何与蒙皮程序');
   }
   assert.deepEqual(errors,[]);
  }finally{await browser.close();}
 }
 fs.writeFileSync(process.env.HXMAKER_TEST_REPORT||'Validation/2026-10-19-deep-checks.json',JSON.stringify(report,null,2)+'\n');
})().catch(e=>{console.error(e);process.exitCode=1;});
