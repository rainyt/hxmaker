import {CDP} from './cdp.mjs';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
const targets=await(await fetch(process.env.CDP_ENDPOINT?`${process.env.CDP_ENDPOINT}/json/list`:'http://127.0.0.1:9425/json/list')).json();
const cdp=await CDP.connect(targets.find(x=>x.type==='page').webSocketDebuggerUrl);
await cdp.call('Page.enable');await cdp.call('Runtime.enable');
await cdp.call('Page.navigate',{url:'http://127.0.0.1:8876/?memory='+Date.now()});
await new Promise(resolve=>setTimeout(resolve,1000));
const report={passed:false,checkpoints:[]};
async function heapCounts(){
 const chunks=[];const original=cdp.socket.onmessage;
 cdp.socket.onmessage=event=>{const message=JSON.parse(event.data);if(message.method==='HeapProfiler.addHeapSnapshotChunk')chunks.push(message.params.chunk);original(event);};
 try{await cdp.call('HeapProfiler.takeHeapSnapshot',{reportProgress:false});}finally{cdp.socket.onmessage=original;}
 const heap=JSON.parse(chunks.join(''));const fields=heap.snapshot.meta.node_fields;const step=fields.length;
 const typeIndex=fields.indexOf('type'),nameIndex=fields.indexOf('name'),sizeIndex=fields.indexOf('self_size');
 const types=heap.snapshot.meta.node_types[typeIndex];const constructors={},sizes={};
 for(let offset=0;offset<heap.nodes.length;offset+=step){
  const type=types[heap.nodes[offset+typeIndex]],name=heap.strings[heap.nodes[offset+nameIndex]];
  sizes[type]=(sizes[type]||0)+heap.nodes[offset+sizeIndex];
  if(type==='object'&&/BitmapData|TextureRecord|DirectBatchDisplay|LayerShader|ImageBufferData|WebGLTexture|StageBitmapEntry/.test(name))constructors[name]=(constructors[name]||0)+1;
 }
 return{constructors,sizes};
}
try{
 for(let index=0;index<1000;index++){
  await cdp.evaluate('new Promise(resolve=>{let n=3;function frame(){window.__stability.step();if(--n<=0)requestAnimationFrame(resolve);else requestAnimationFrame(frame);}requestAnimationFrame(frame);})');
  if([9,99,499,999].includes(index)){
   await cdp.call('HeapProfiler.collectGarbage');
   const value=await cdp.evaluate('({state:window.__stability.snapshot(),heap:performance.memory.usedJSHeapSize})');
   const entry={cycles:index+1,state:value.state,heapBytes:value.heap};
   if(index===9||index===999)entry.heapSnapshot=await heapCounts();
   report.checkpoints.push(entry);assert.equal(value.state.diagnostics.faults,0);assert.equal(value.state.diagnostics.pendingDisposals,0);
   console.log(JSON.stringify({cycles:index+1,heap:value.heap,references:value.state.diagnostics.references,constructors:entry.heapSnapshot?.constructors}));
  }
 }
 const first=report.checkpoints[0],last=report.checkpoints.at(-1);
 assert.equal(last.state.diagnostics.references,first.state.diagnostics.references);
 assert.equal(last.state.pool,first.state.pool);
 for(const [name,count] of Object.entries(first.heapSnapshot.constructors))assert.equal(last.heapSnapshot.constructors[name],count,`存活对象增长：${name}`);
 report.retainedConstructorsStable=true;
 report.passed=true;
}finally{await fs.writeFile(new URL('../results/memory.json',import.meta.url),JSON.stringify(report,null,2));cdp.close();}
