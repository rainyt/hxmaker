// 距离雾 GPU 回归；需要带 hxmaker_fog_checks 的 HTML5 示例。
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const base=process.env.HXMAKER_TEST_BASE||'http://127.0.0.1:8733';
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{}),args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader',...(process.env.HXMAKER_WEBGL1?['--disable-webgl2']:[])]});
 try{
 const page=await browser.newPage({viewport:{width:1000,height:700}}),errors=[];
 page.on('pageerror',error=>errors.push(error.stack));page.on('console',message=>{if(message.type()==='error'&&!message.text().includes('favicon'))errors.push(message.text());});
 await page.goto(`${base}/samples/3d/distance-fog/Export/html5/bin/`);
 await page.waitForFunction(()=>window.__hxmakerFog?.state().stats.drawCalls===1,null,{timeout:20000});
 const state=()=>page.evaluate(()=>window.__hxmakerFog.state());
 const pixel=(x=.5,y=.5)=>page.evaluate(([x,y])=>window.__hxmakerFog.pixel(x,y),[x,y]);
 const report={browser:browser.version(),backend:'软件 WebGL，仅验证功能',webgl:(await state()).webgl,vao:(await state()).stats.stateVao,cases:[]};
 const pass=message=>{report.cases.push(message);console.log('PASS '+message);};
 const close=(actual,expected,label,tolerance=3)=>assert(actual.every((value,index)=>Math.abs(value-expected[index])<=tolerance),`${label}：${actual} / ${expected}`);
 const linear=v=>v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4);
 const display=v=>Math.round(255*(v<=.0031308?v*12.92:1.055*Math.pow(v,1/2.4)-.055));
 const mixed=factor=>[255,0,0].map((value,index)=>display(linear(value/255)*(1-factor)+linear([128,160,192][index]/255)*factor));
 async function command(name){const id=(await state()).stats.redrawId;await page.evaluate(name=>window.__hxmakerFog.command(name),name);await page.waitForFunction(id=>window.__hxmakerFog.state().stats.redrawId>id,id);assert.equal((await state()).error,0,name);}
 if(process.env.HXMAKER_WEBGL1)assert.match(report.webgl,/WebGL 1/);
 if(process.env.HXMAKER_NO_VAO)assert.equal(report.vao,false);
 close(await pixel(),[255,0,0,255],'默认关闭');
 await command('linear');close(await pixel(),[...mixed(.5),255],'线性雾');assert.equal((await state()).stats.drawCalls,1);pass('线性雾像素正确且不增加模型批次');
 const centerIndex=63,edgeIndex=Math.floor(.9*127);const ndc=index=>(index+.5)/128*2-1;
 const z=10,x=ndc(edgeIndex)*z/Math.sqrt(3),y=ndc(centerIndex)*z/Math.sqrt(3);
 close(await pixel(.9,.5),[...mixed((Math.sqrt(x*x+y*y+z*z)-5)/10),255],'欧氏距离');pass('大片三角形逐片元径向距离，视口边缘不是平面深度雾');
 await command('translate');close(await pixel(),[128,160,192,255],'相机移动');await command('reset');pass('相机移动触发距离变化');
 await command('exp');close(await pixel(),[...mixed(1-Math.exp(-1)),255],'指数雾');await command('exp2');close(await pixel(),[...mixed(1-Math.exp(-4)),255],'平方指数雾');await command('zero');close(await pixel(),[255,0,0,255],'零密度');pass('指数、平方指数和零密度');
 await command('reset');await command('partial');close(await pixel(),[...mixed(.25),255],'最大雾量');await command('reset');
 const first=(await state()).stats.redrawId;await page.waitForTimeout(250);assert.equal((await state()).stats.redrawId,first);pass('最大雾量与按需重绘缓存');
 await command('lambert');close(await pixel(),[...mixed(.5),255],'Lambert');await command('pbr');close(await pixel(),[...mixed(.5),255],'PBR');await command('unlit');pass('无光照、Lambert 和 PBR 材质');
 await command('transparent');close(await pixel(),[...mixed(.5).map(value=>Math.round(value*.5)),128],'透明预乘');await command('soft');assert.equal((await state()).stats.softParticleStatus,'启用');close(await pixel(),[...mixed(.5).map(value=>Math.round(value*.5)),128],'软粒子');pass('透明预乘与软粒子深度通道兼容');
 await command('add');await command('full');close(await pixel(),[0,0,0,0],'远处加法光淡出');await command('mask');close(await pixel(),[0,0,0,0],'MASK 保持裁剪');pass('加法特效不染雾色，MASK 保持裁剪');
 await command('opaque');await command('sky');const sky=await pixel();assert(sky[3]===255&&sky.some((value,index)=>index<3&&value!==[128,160,192][index]));await command('skyFog');close(await pixel(),[128,160,192,255],'天空混雾');pass('天空可选混雾，默认独立');
 await command('bloom');assert.equal((await state()).stats.bloomStatus,'启用');pass('雾在 Bloom 前生效');
 await command('low');assert.match((await state()).stats.fogStatus,/片元精度/);await command('high');assert.equal((await state()).stats.fogStatus,'启用');pass('低精度参数超限回退与恢复');
 const before=await pixel();await page.evaluate(()=>window.__hxmakerFog.command('lose'));await page.waitForFunction(()=>window.__hxmakerFog.state().error===-1);await page.waitForFunction(()=>window.__hxmakerFog.state().error===0&&window.__hxmakerFog.pixel().length===4,null,{timeout:20000});close(await pixel(),before,'上下文恢复');pass('上下文恢复重建带雾绘制');
 assert.deepEqual(errors,[]);if(process.env.HXMAKER_TEST_REPORT)fs.writeFileSync(process.env.HXMAKER_TEST_REPORT,JSON.stringify(report,null,2)+'\n');
 await page.screenshot({path:'/tmp/hxmaker-fog-checks.png'});console.log('HXMAKER_FOG_BROWSER PASS '+report.cases.length);
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
