// 完整探索流程回归：通过真实键盘行走和交互，测试宏只负责读取状态及定位朝向。
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const base=process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733';
(async()=>{
const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
try{
 const page=await browser.newPage({viewport:{width:1120,height:760}}),errors=[];
 page.on('pageerror',error=>errors.push(error.stack));page.on('console',message=>{if(message.type()==='error'&&!message.text().includes('favicon'))errors.push(message.text());});
 const url=`${base}/samples/3d/away3d-explorer/Export/html5/bin/`;
 const state=()=>page.evaluate(()=>window.__hxmakerExplorer.state());
 const command=(name,x=0,z=0)=>page.evaluate(([name,x,z])=>window.__hxmakerExplorer.command(name,x,z),[name,x,z]);
 async function ready(){await page.waitForFunction(()=>window.__hxmakerExplorer?.state().failure||window.__hxmakerExplorer?.state().ready&&window.__hxmakerExplorer.state().stats.drawCalls>0,null,{timeout:45000});assert.equal((await state()).failure,'');}
 const report={browser:browser.version(),backend:'软件 WebGL，仅验证功能',cases:[]};
 const pass=message=>{report.cases.push(message);console.log('PASS '+message);};
 async function walk(x,z){
  const deadline=Date.now()+35000;await page.keyboard.down('Shift');await page.keyboard.down('w');
  try{while(true){const current=await state(),distance=Math.hypot(current.position[0]-x,current.position[2]-z);if(distance<.75)break;
   if(Date.now()>deadline)throw new Error(`行走超时 ${x},${z}，当前位置 ${current.position}`);
   await command('face',x,z);await page.waitForTimeout(70);
  }}finally{await page.keyboard.up('w');await page.keyboard.up('Shift');}
 }
 await page.goto(url);await ready();await command('reset');await page.waitForFunction(()=>window.__hxmakerExplorer.state().grounded);
 await page.waitForTimeout(300);const cachedId=(await state()).stats.redrawId;await page.waitForTimeout(350);assert.equal((await state()).stats.redrawId,cachedId,'角色静止时应复用三维画面');pass('静止时复用三维缓存');
 assert.equal((await state()).stats.fogStatus,'启用');assert.equal((await state()).stats.skyboxDrawCalls,1);
 await page.screenshot({path:'/tmp/hxmaker-explorer-initial.png'});pass('Blender GLB、天空、IBL、距离雾与碰撞世界加载');
 const yaw=(await state()).yaw;await page.mouse.move(520,400);await page.mouse.down();await page.mouse.move(650,430,{steps:5});await page.mouse.up();assert(Math.abs((await state()).yaw-yaw)>.2);pass('真实鼠标拖动环顾');
 await page.keyboard.press('Space');await page.waitForFunction(()=>window.__hxmakerExplorer.state().position[1]>.15);await page.waitForFunction(()=>window.__hxmakerExplorer.state().grounded);pass('跳跃并回落到碰撞地面');
 await command('teleport',0,-5);await command('face',0,-20);await page.keyboard.down('w');await page.waitForTimeout(1500);await page.keyboard.up('w');
 assert((await state()).position[2]>-8.6,'关闭的门应阻挡角色');await page.keyboard.press('e');assert.equal((await state()).gateOpen,false);pass('闸门真实阻挡，任务未完成不能打开');
 await page.keyboard.press('r');await page.waitForFunction(()=>window.__hxmakerExplorer.state().position[2]>26);await walk(0,9);
 await page.keyboard.press('e');assert.match((await state()).hint,/机器人/);pass('行走接近并与导览机器人交互');
 await walk(7,25);await page.keyboard.press('e');await page.waitForFunction(()=>window.__hxmakerExplorer.state().collected.includes('south'));pass('探索并激活南侧信标');
 await walk(22,20);await walk(22,-10);await walk(22,-14);await page.keyboard.press('e');await page.waitForFunction(()=>window.__hxmakerExplorer.state().collected.includes('east'));pass('绕过建筑并激活东侧信标');
 await walk(18,-3);await walk(-17,-3);await page.keyboard.press('e');await page.waitForFunction(()=>window.__hxmakerExplorer.state().collected.length===3);pass('穿过庭院并激活西侧信标');
 await walk(0,-4);await walk(0,-6.4);await page.keyboard.press('e');assert.equal((await state()).gateOpen,true);
 await walk(0,-19.2);await page.keyboard.press('e');await page.waitForFunction(()=>window.__hxmakerExplorer.state().complete);pass('开启闸门、实际穿过门洞并完成档案任务');
 await page.screenshot({path:'/tmp/hxmaker-explorer-complete.png'});
 await page.keyboard.press('k');const saved=await state();await page.reload();await ready();
 let restored=await state();assert.deepEqual(restored.collected.slice().sort(),['east','south','west']);assert(restored.complete&&restored.gateOpen);assert(Math.hypot(saved.position[0]-restored.position[0],saved.position[2]-restored.position[2])<.5);pass('页面刷新恢复任务、闸门和玩家位置');
 await page.keyboard.press('f');await page.waitForFunction(()=>!window.__hxmakerExplorer.state().fog);await page.keyboard.press('f');await page.waitForFunction(()=>window.__hxmakerExplorer.state().fog);pass('键盘切换距离雾');
 for(let index=0;index<2;index++){await command('restart');await ready();restored=await state();assert(restored.complete);assert.deepEqual(restored.lastRelease,{sceneDisposed:true,controllerDisposed:true,collisionDisposed:true,colliders:0,nodes:0});}
 pass('两次销毁重进，释放控制器、场景和碰撞代理');
 await command('reset');await page.waitForFunction(()=>window.__hxmakerExplorer.state().grounded);const before=(await state()).position;
 const canvas=await page.locator('canvas').boundingBox(),inputScale=(await state()).inputScale;await page.mouse.move(canvas.x+106*inputScale,canvas.y+574*inputScale);await page.mouse.down();await page.waitForTimeout(700);await page.mouse.up();assert((await state()).position[2]<before[2]-.5);pass('屏幕方向按钮支持持续移动并在抬起时停止');
 assert.deepEqual(errors,[]);report.final=await state();
 if(process.env.HXMAKER_TEST_REPORT)fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');
 console.log('HXMAKER_EXPLORER_BROWSER PASS '+report.cases.length);
}finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
