import {CDP} from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const endpoint=process.env.CDP_ENDPOINT||'http://127.0.0.1:9425';
const targets=await(await fetch(`${endpoint}/json/list`)).json();
const cdp=await CDP.connect(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
await cdp.call('Page.enable');await cdp.call('Runtime.enable');await cdp.call('Network.enable');
await cdp.call('Network.setCacheDisabled',{cacheDisabled:true});
await cdp.call('Emulation.setDeviceMetricsOverride',{width:960,height:640,deviceScaleFactor:1,mobile:false});
const results=[];
const javascript={};
for(const mode of ['before','after'])javascript[mode]=createHash('sha256').update(await fs.readFile(new URL(`../Export/html5/bin/benchmark-${mode}.js`,import.meta.url))).digest('hex');
try {
 for(let round=0;round<5;round++)for(const textures of [1,6])for(const mode of round%2?['after','before']:['before','after']) {
  const params=new URLSearchParams({count:10000,textures,scenario:'moving',warmup:4000,duration:8000,mode,diagnostic:1});
  await cdp.call('Page.navigate',{url:`http://127.0.0.1:8876/benchmark-${mode}.html?${params}`});
  await new Promise(resolve=>setTimeout(resolve,200));cdp.events.length=0;
  const deadline=Date.now()+20000;
  let done=false;
  while(Date.now()<deadline) {
   await new Promise(resolve=>setTimeout(resolve,100));
   if(await cdp.evaluate('Boolean(window.__benchmark?.done)')){done=true;break;}
  }
  assert.equal(done,true,`性能场景超时：${mode}/${textures}`);
  const value=await cdp.evaluate('window.__benchmark.result');
  const errors=cdp.events.filter(x=>x.method==='Runtime.exceptionThrown');assert.equal(errors.length,0);
  const entry={round,mode,textures,...value};results.push(entry);
  console.log(JSON.stringify({round,mode,textures,frames:value.frames,p95:value.metrics.frameCpu.p95,p50:value.metrics.frameCpu.p50,draws:value.metrics.draws.mean}));
 }
 const summaries=[];
 for(const textures of [1,6]) {
  const median=values=>values.sort((a,b)=>a-b)[Math.floor(values.length/2)];
  const before=median(results.filter(x=>x.textures===textures&&x.mode==='before').map(x=>x.metrics.frameCpu.p95));
  const after=median(results.filter(x=>x.textures===textures&&x.mode==='after').map(x=>x.metrics.frameCpu.p95));
  summaries.push({textures,beforeP95:before,afterP95:after,changePercent:(after/before-1)*100,thresholdPercent:5,passed:after<=before*1.05});
 }
 await fs.writeFile(new URL('../results/performance.json',import.meta.url),JSON.stringify({createdAt:new Date().toISOString(),beforeCore:'f879909',beforeBackend:'caac7ba',resolution:[960,640],objects:10000,rounds:5,instrumentedDraws:true,javascript,summaries,results},null,2));
 console.log(JSON.stringify(summaries));assert.ok(summaries.every(x=>x.passed),'P95 超过5%回归阈值，需要分析并复测');
} finally{cdp.close();}
