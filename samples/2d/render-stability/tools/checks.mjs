import { CDP } from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const endpoint=process.env.CDP_ENDPOINT||'http://127.0.0.1:9425';
const targets=await(await fetch(`${endpoint}/json/list`)).json();
const cdp=await CDP.connect(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
await cdp.call('Page.enable'); await cdp.call('Runtime.enable');
const results=[];
try {
 for(const [name,file] of [
  ['direct-batch-indices','direct-batch-indices-check.js'],
  ['direct-batch-samplers','direct-batch-samplers-check.js'],
  ['blend-mode-texture-lifetime','blend-mode-texture-lifetime-check.js'],
  ['stale-sampler-before','stale-sampler-repro-before.js'],
  ['stale-sampler-after','stale-sampler-repro-after.js']]) {
  await cdp.call('Page.navigate',{url:'about:blank'});
  await new Promise(resolve=>setTimeout(resolve,100)); cdp.events.length=0;
  const script=await fs.readFile(new URL(`../../../../bin/${file}`,import.meta.url),'utf8');
  try {await cdp.evaluate(script);}
  catch(error){results.push({name,passed:false,error:String(error)});throw error;}
  const errors=cdp.events.filter(x=>x.method==='Runtime.exceptionThrown');
  assert.equal(errors.length,0,JSON.stringify(errors));
  results.push({name,passed:true});console.log(`${name}：通过`);
 }
} finally {
 await fs.writeFile(new URL('../results/protocol-checks.json',import.meta.url),JSON.stringify(results,null,2));cdp.close();
}
