package;

import hx.core.Render;
import js.Browser;

/** 完整包住 OpenFL 的帧回调；分段值仅用于解释，不能与完整帧耗时重复相加。 */
@:access(openfl.display.Stage)
class BenchmarkProbe {
	public static var state:Dynamic;
	public static function install(render:Render, config:Dynamic):Void {
		var stage = openfl.Lib.current.stage;
		state = js.Syntax.code("(function(render,stage,config){
			var capacity=60000, names=['interval','frameCpu','update','build','render','draws','uploadBytes','uploadCalls'];
			var p={config:config,ready:true,done:false,count:0,frame:0,last:0,start:0,updateMs:0,buildMs:0,renderMs:0,draws:0,uploadBytes:0,uploadCalls:0};
			p.restoreContext=function(){return new Promise(function(resolve,reject){var gl=stage.__renderer.gl,extension=gl.getExtension('WEBGL_lose_context');if(!extension){reject(new Error('没有上下文恢复扩展'));return;}gl.canvas.addEventListener('webglcontextrestored',function(){setTimeout(resolve,500);},{once:true});extension.loseContext();setTimeout(function(){extension.restoreContext();},200);});};
			var samples={}; for(var name of names) samples[name]=new Float64Array(capacity);
			function wrap(object,name,before,after){ var original=object[name]; object[name]=function(){if(before)before(); var start=performance.now();try{return original.apply(this,arguments);}finally{if(after)after(performance.now()-start);}}; }
			var buildStart=0;
			wrap(render,'clear',function(){buildStart=performance.now();},null);
			wrap(render,'endFill',null,function(){p.buildMs+=performance.now()-buildStart;});
			wrap(stage.__renderer,'__render',null,function(ms){p.renderMs+=ms;});
			if(config.diagnostic){
				var gl=stage.__renderer.gl;
				for(var name of ['drawArrays','drawElements'])wrap(gl,name,function(){p.draws++;},null);
				for(var name of ['bufferData','bufferSubData'])(function(name){
					var original=gl[name]; gl[name]=function(){var data=arguments[name==='bufferData'?1:2];p.uploadCalls++;p.uploadBytes+=typeof data==='number'?data:(data?data.byteLength:0);return original.apply(this,arguments);};
				})(name);
			}
			function summary(name){var list=Array.from(samples[name].subarray(0,p.count)).sort(function(a,b){return a-b;});var sum=0;for(var x of list)sum+=x;return {mean:sum/list.length,p50:list[Math.ceil(list.length*.50)-1],p95:list[Math.ceil(list.length*.95)-1],p99:list[Math.ceil(list.length*.99)-1],max:list[list.length-1]};}
			p.begin=function(){p.updateMs=p.buildMs=p.renderMs=p.draws=p.uploadBytes=p.uploadCalls=0;};
			p.finish=function(cpu,now){
				if(p.done)return;
				p.frame++; if(!p.start)p.start=now;
				var interval=p.last?now-p.last:0;p.last=now;
				if(now-p.start<config.warmup)return;
				if(!p.sampleStart)p.sampleStart=now;
				if(interval>0&&p.count<capacity){var i=p.count++;samples.interval[i]=interval;samples.frameCpu[i]=cpu;samples.update[i]=p.updateMs;samples.build[i]=p.buildMs;samples.render[i]=p.renderMs;samples.draws[i]=p.draws;samples.uploadBytes[i]=p.uploadBytes;samples.uploadCalls[i]=p.uploadCalls;}
				if(now-p.sampleStart>=config.duration||p.count===capacity){
					var result={config:config,frames:p.count,elapsed:now-p.sampleStart,visibility:document.visibilityState,metrics:{},gpuMs:null,memory:performance.memory?performance.memory.usedJSHeapSize:null,webglVersion:stage.__renderer.gl.getParameter(stage.__renderer.gl.VERSION)};
					for(var name of names)result.metrics[name]=summary(name);
					if(!config.diagnostic){result.metrics.draws=null;result.metrics.uploadBytes=null;result.metrics.uploadCalls=null;}
					result.fps=1000/result.metrics.interval.mean;
					result.overBudget=Array.from(samples.interval.subarray(0,p.count)).filter(function(x){return x>1000/60*1.1;}).length;
					result.directBatches=render.directBatches||0;result.fallbackBatches=render.fallbackBatches||0;
					p.result=result;p.done=true;
					document.title='已完成 · '+config.mode+' · '+config.count;
					var output=document.createElement('pre');output.id='benchmark-result';output.style='position:fixed;left:8px;top:8px;margin:0;padding:12px;background:#101826e8;color:#fff;font:13px monospace;pointer-events:none';
					output.textContent='模式：'+config.mode+'  对象：'+config.count+'  纹理：'+config.textures+'\\n完整帧 CPU：'+result.metrics.frameCpu.mean.toFixed(3)+' ms  P95：'+result.metrics.frameCpu.p95.toFixed(3)+' ms\\n帧率：'+result.fps.toFixed(1)+'  样本：'+p.count+'\\n控制台 window.__benchmark.result 可读取完整结果';document.body.appendChild(output);
				}
			};
			p.raw=function(){var result={};for(var name of names)result[name]=Array.from(samples[name].subarray(0,p.count));return result;};
			window.__benchmark=p;
			return p;
		})({0},{1},{2})", render, stage, config);
		var original = stage.__onLimeRender;
		stage.window.onRender.remove(original);
		stage.window.onRender.add(context -> {
			state.begin();
			var start = Browser.window.performance.now();
			original(context);
			var now = Browser.window.performance.now();
			state.finish(now - start, now);
		});
	}
}
