import {CDP} from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const endpoint=process.env.CDP_ENDPOINT||'http://127.0.0.1:9425';
const targets=await(await fetch(`${endpoint}/json/list`)).json();
const cdp=await CDP.connect(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
await cdp.call('Page.enable');await cdp.call('Runtime.enable');
cdp.events.length=0;
const report={passed:false};
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function waitFor(expression){const deadline=Date.now()+10000;while(Date.now()<deadline){if(await cdp.evaluate(expression))return;await pause(50);}throw new Error('等待超时：'+expression);}
try {
 report.before=await cdp.evaluate('window.__stability.snapshot()');
 assert.equal(report.before.astc.enabled,true);
 assert.equal(report.before.astc.ready,true);
 await cdp.evaluate(`(() => {
   const canvas=document.querySelector('canvas');
   const gl=canvas.getContext('webgl2')||canvas.getContext('webgl')||canvas.getContext('experimental-webgl');
   window.__originalExtension=gl.getExtension;
   gl.getExtension=function(name){if(name==='WEBGL_compressed_texture_astc')return null;return window.__originalExtension.call(gl,name);};
   window.__faultGL=gl;
 })()`);
 const recovered=report.before.recovered;
 assert.equal(await cdp.evaluate('window.__stability.lose()'),true);
 await waitFor(`window.__stability.snapshot().recovered>${recovered} && window.__stability.snapshot().astc.fallback`);
 await pause(250);
 report.fallback=await cdp.evaluate('window.__stability.snapshot()');
 assert.equal(report.fallback.astc.bytes,0);
 assert.ok(report.fallback.diagnostics.reports.some(x=>x.kind==='notReady'&&x.input==='ASTC'));
 const shot=await cdp.call('Page.captureScreenshot',{format:'png'});
 await fs.writeFile(new URL('../results/astc-fallback.png',import.meta.url),Buffer.from(shot.data,'base64'));
 await cdp.evaluate('window.__faultGL.getExtension=window.__originalExtension;delete window.__faultGL;delete window.__originalExtension;');
 for(let index=0;index<70;index++){
  await cdp.evaluate('window.__stability.inject("disposed")');await pause(35);
  await cdp.evaluate('window.__stability.clearFault()');await pause(20);
 }
 report.after=await cdp.evaluate('window.__stability.snapshot()');
 assert.equal(report.after.diagnostics.reports.length,64);
 assert.equal(report.after.diagnostics.references,report.before.diagnostics.references);
 assert.equal(report.after.diagnostics.pendingDisposals,0);
 assert.equal(cdp.events.filter(x=>x.method==='Runtime.exceptionThrown').length,0);
 report.passed=true;
 console.log(JSON.stringify({fallback:report.fallback.astc,diagnosticEntries:report.after.diagnostics.reports.length,references:report.after.diagnostics.references,passed:true}));
}finally{await fs.writeFile(new URL('../results/fault-budget.json',import.meta.url),JSON.stringify(report,null,2));cdp.close();}
