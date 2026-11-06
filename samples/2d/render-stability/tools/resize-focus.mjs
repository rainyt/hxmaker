import { CDP } from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

// 回归窗口仍可见但失去焦点的路径，验证过程不点击游戏，不强制恢复主页面焦点。
const endpoint=process.env.CDP_ENDPOINT||'http://127.0.0.1:9425';
const broken=process.argv.includes('--expect-broken');
const directory=new URL('../results/resize-focus/',import.meta.url);
await fs.mkdir(directory,{recursive:true});
const version=await(await fetch(`${endpoint}/json/version`)).json();
const browser=await CDP.connect(version.webSocketDebuggerUrl);
const targets=await(await fetch(`${endpoint}/json/list`)).json();
const target=targets.find(x=>x.type==='page'&&x.url.includes('127.0.0.1:8876'))||targets.find(x=>x.type==='page');
const cdp=await CDP.connect(target.webSocketDebuggerUrl);
await cdp.call('Page.enable');await cdp.call('Runtime.enable');await cdp.call('Network.enable');
await cdp.call('Network.setCacheDisabled',{cacheDisabled:true});
const report={passed:false,expectedBroken:broken,version,states:[],screenshots:[],focusDriver:'DOM blur 经现有 Lime/OpenFL 事件转发'};
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
let auxiliary;
async function waitFor(expression){const deadline=Date.now()+10000;while(Date.now()<deadline){if(await cdp.evaluate(expression))return;await pause(40);}throw new Error('等待超时：'+expression);}
async function state(name){const value=await cdp.evaluate('({engine:window.__stability.snapshot(),hidden:document.hidden,visibility:document.visibilityState,focused:document.hasFocus(),events:window.__focusEvents})');report.states.push({name,...value});return value;}
async function shot(name){const image=await cdp.call('Page.captureScreenshot',{format:'png'});await fs.writeFile(new URL(`${name}.png`,directory),Buffer.from(image.data,'base64'));report.screenshots.push(`${name}.png`);}
async function viewport(width,height){await cdp.call('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:1,mobile:false});await pause(100);}
try{
 await viewport(960,640);
 await cdp.call('Page.navigate',{url:'http://127.0.0.1:8876/?resize-focus='+Date.now()});
 await waitFor('Boolean(window.__stability?.ready)');
 await waitFor('!window.__stability.snapshot().astc.enabled||window.__stability.snapshot().astc.ready');
 await pause(250);cdp.events.length=0;
 await cdp.evaluate(`window.__focusEvents=[];for(const name of ['focus','blur','mousedown'])window.addEventListener(name,event=>window.__focusEvents.push({type:event.type,trusted:event.isTrusted}));document.addEventListener('visibilitychange',event=>window.__focusEvents.push({type:event.type,hidden:document.hidden,trusted:event.isTrusted}));`);
 const initial=await state('初始');await shot(broken?'before-initial':'after-initial');
 try{
  auxiliary=(await browser.call('Target.createTarget',{url:'about:blank',newWindow:true})).targetId;
  await browser.call('Target.activateTarget',{targetId:auxiliary});await pause(150);
 }catch(error){report.nativeFocusError=String(error);}
 let blurred=await state('切换其他浏览器窗口后');
 if(!blurred.hidden&&blurred.events.some(x=>x.type==='blur'))report.focusDriver='独立浏览器窗口切换';
 else{
  // 无原生焦点支持的 headless 环境仍走真实 DOM→Lime→OpenFL 转发，避免直接调用引擎开关。
  if(blurred.hidden){
   if(auxiliary){await browser.call('Target.closeTarget',{targetId:auxiliary});auxiliary=null;}
   await browser.call('Target.activateTarget',{targetId:target.id});await waitFor('!document.hidden');await pause(100);
   await cdp.evaluate('window.__focusEvents=[]');
  }
  await cdp.evaluate('window.dispatchEvent(new Event("blur"))');await pause(80);blurred=await state('可见页面发送 blur 后');
 }
 assert.equal(blurred.hidden,false,'本用例要求页面可见，不能用切到隐藏标签代替失焦');
 await viewport(800,600);await pause(150);
 const resized=await state('失焦时缩放后');await shot(broken?'before-blurred-resize':'after-blurred-resize');
 assert.equal(resized.engine.windowWidth,800);assert.equal(resized.engine.windowHeight,600);
 if(broken){
  assert.equal(resized.engine.applicationVisible,false);
  assert.equal(resized.engine.updateCount,blurred.engine.updateCount);
  assert.equal(resized.engine.diagnostics.drawn,blurred.engine.diagnostics.drawn);
  assert.equal(resized.engine.resizePending,true);
  await cdp.evaluate('window.dispatchEvent(new Event("focus"))');await pause(150);
  const resumed=await state('模拟重新点击获得焦点后');await shot('before-focus-restored');
  assert.equal(resumed.engine.applicationVisible,true);assert.ok(resumed.engine.diagnostics.drawn>resized.engine.diagnostics.drawn);
 }else{
  assert.equal(resized.engine.applicationVisible,true);assert.ok(resized.engine.updateCount>blurred.engine.updateCount);
  assert.ok(resized.engine.diagnostics.drawn>blurred.engine.diagnostics.drawn);assert.equal(resized.engine.resizePending,false);
  for(let index=0;index<40;index++){
   await viewport(index%2?800:960,index%2?600:640);
   const current=await cdp.evaluate('window.__stability.snapshot()');
   assert.equal(current.applicationVisible,true);assert.equal(current.resizePending,false);assert.equal(current.diagnostics.faults,0);
  }
  const idleBefore=await state('失焦持续更新开始');await pause(400);const idleAfter=await state('未点击且仍失焦的后续帧');
  assert.ok(idleAfter.engine.updateCount>idleBefore.engine.updateCount);
  assert.equal(idleAfter.events.filter(x=>x.type==='focus'||x.type==='mousedown').length,0,'缩放验证中发生了焦点恢复或点击');
  await viewport(960,640);await shot('after-unfocused-restored-size');
  assert.equal(idleAfter.engine.generation,initial.engine.generation);
  // 页面真正隐藏仍必须暂停；恢复可见但不发送 focus，也必须恢复。
  await cdp.evaluate(`window.__testHidden=true;Object.defineProperty(document,'hidden',{configurable:true,get:()=>window.__testHidden});Object.defineProperty(document,'visibilityState',{configurable:true,get:()=>window.__testHidden?'hidden':'visible'});document.dispatchEvent(new Event('visibilitychange'));`);
  const hiddenBefore=await state('隐藏事件后');await pause(150);const hiddenAfter=await state('隐藏期间');
  assert.equal(hiddenAfter.engine.applicationVisible,false);assert.equal(hiddenAfter.engine.updateCount,hiddenBefore.engine.updateCount);
  await cdp.evaluate(`window.__testHidden=false;document.dispatchEvent(new Event('visibilitychange'));`);await pause(150);
  const visible=await state('仅恢复可见，不发送 focus');
  assert.equal(visible.engine.applicationVisible,true);assert.ok(visible.engine.updateCount>hiddenAfter.engine.updateCount);
  assert.ok(visible.engine.diagnostics.drawn>hiddenAfter.engine.diagnostics.drawn,'恢复可见后必须实际重绘');
  await shot('after-visible-without-focus');
  await cdp.evaluate(`delete document.hidden;delete document.visibilityState;delete window.__testHidden;`);
 }
 assert.equal(cdp.events.filter(x=>x.method==='Runtime.exceptionThrown').length,0);
 report.passed=true;console.log(JSON.stringify({passed:true,expectedBroken:broken,focusDriver:report.focusDriver,states:report.states.map(x=>({name:x.name,visible:x.engine.applicationVisible,hidden:x.hidden,updates:x.engine.updateCount,drawn:x.engine.diagnostics.drawn,pending:x.engine.resizePending}))}));
}catch(error){report.error=String(error.stack||error);await shot(broken?'before-failed':'after-failed');throw error;}
finally{
 await fs.writeFile(new URL(broken?'before.json':'after.json',directory),JSON.stringify(report,null,2));
 if(auxiliary)await browser.call('Target.closeTarget',{targetId:auxiliary});
 cdp.close();browser.close();
}
