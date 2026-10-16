package;

import hx.assets.Assets;
import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Sprite;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.net.RequestQueue;

/** 独立验收台；启动后仅显示场景，所有采样、循环和上下文诊断由用户按钮触发。 */
class Main extends openfl.display.Sprite {
	private var pool:Assets;
	private var manifest:Dynamic;
	private var world:AcceptanceWorld;
	private var sampler:FrameSampler;
	private var holder:Sprite;
	private var heartbeat:Quad;
	private var recorder = new BaselineRecorder();
	private var cases = Cases.suite();
	private var selected:Int = 3;
	private var suiteRunning:Bool = false;
	private var soakRunning:Bool = false;
	private var soakSampledMs:Float = 0;
	private var lifecycle:LifecycleRun;
	private var lifecycleReports:Array<Dynamic> = [];
	private var poolLoads:Array<Dynamic> = [];
	private var poolReferenceBaseline:Int = 0;
	private var diagnostics:Array<Dynamic> = [];
	private var problems:Array<String> = [];
	private var loading:Bool = false;
	private var diagnostic:Bool = false;
	private var pendingAdvance:Bool = false;
	private var state:Label;
	private var title:Label;
	private var progress:Label;
	private var live:Label;
	private var summary:Label;
	private var verdict:Label;
	private var statusMs:Float = 0;
	private var heartbeatFrame:Int = 0;
	private var wasHidden:Bool = false;
	private var windowKey:String;
	private var lastInput:Dynamic;
	private var contextLost:Bool = false;
	private var contextSequence:Int = 0;
	private var contextRestoredAt:Float = 0;
	private var currentMetadata:Dynamic;
	#if (js && html5)
	private var recoveryPanel:js.html.DivElement;
	#end

	public function new() {
		super();
		var engine = Hxmaker.init(Engine,1280,800); engine.initOpenFLRoot(this); engine.frameRate = 60;
		Hxmaker.topView.addChild(new Quad(1280,800,0x162134));
		label("3D 引擎验收与性能基线",20,16,26,0xffffff);
		action("下一个场景",20,62,function() { if (busy()) return; diagnostic=false; selected = (selected+1)%cases.length; rebuild(); });
		action("采样当前",210,62,function() { if (busy()) return; startSampling(false); });
		action("运行完整套件",380,62,function() { if (busy()) return; suiteRunning = true; selected = 0; startSampling(false); });
		action("长跑 5 分钟",590,62,function() { if (busy()) return; soakRunning = true; soakSampledMs=0; startSampling(true); });
		action("停止",800,62,stop);
		action("导出 JSON",950,62,exportReport);
		action("采样状态诊断",20,103,function() { if (busy()) return; selected = cases.length-1; diagnostic = true; rebuild(); });
		action("资源循环 ×20",240,103,startLifecycle);
		action("记录画面通过",455,103,function() { recordVisual(true); });
		action("记录画面异常",665,103,function() { recordVisual(false); });
		action("上下文恢复诊断",875,103,loseContext);
		action("重载资源",1105,103,function() {
			if (busy()) return; clearWorld(); if (pool != null) { pool.stop(); pool.clean(); pool=null; } loadPool();
		});
		state = label("准备加载固定资源",20,141,15,0xb9cce9);
		title = label("场景：待加载",20,171,18,0xffffff);
		holder = new Sprite(); holder.x = 20; holder.y = 204; Hxmaker.topView.addChild(holder);
		progress = label("尚未采样",950,180,16,0x8ed6ff);
		live = label("",950,225,14,0xb9cce9); live.width = 310;
		summary = label("",950,410,14,0xb9cce9); summary.width = 310;
		verdict = label("功能验收：待人工确认",950,620,14,0xffcc79); verdict.width = 310;
		heartbeat = new Quad(9,9,0x73e0c1); heartbeat.x = 1250; heartbeat.y = 775; Hxmaker.topView.addChild(heartbeat);
		label("耗时口径：帧间隔 + 动画 CPU + 完整 3D 回调 CPU；GPU 时间与实际显存占用未测量。",20,727,14,0xa9bad6);
		label("性能与采样诊断分开运行。切后台或改变窗口尺寸会重新预热；画面结果需要人工记录。",20,754,14,0xa9bad6);
		windowKey = RuntimeInfo.sizeKey(); installBrowserEvents();
		Hxmaker.topView.addEventListener(Event.UPDATE,function(_) { update(); });
		loadPool();
	}
	private function label(text:String,x:Float,y:Float,size:Int,color:Int):Label {
		var result = new Label(text); result.x=x; result.y=y; result.fontSize=size; result.color=color;
		Hxmaker.topView.addChild(result); return result;
	}
	private function action(text:String,x:Float,y:Float,callback:Void->Void):Void {
		var button = label(text,x,y,17,0x8ed6ff); button.addEventListener(MouseEvent.CLICK,function(_) { callback(); });
	}
	private function busy():Bool { return loading || recorder.running || pendingAdvance || suiteRunning || soakRunning || lifecycle != null && lifecycle.busy || contextLost; }
	private function clearWorld():Void {
		if (world != null) {
			if (world.probe != null) diagnostics.push({caseId:world.configuration.id,verified:world.probe.verified,nearestFrames:world.probe.nearestFrames,linearFrames:world.probe.linearFrames,failures:world.probe.failures.copy()});
			world.dispose(); world = null;
		}
		sampler = null; lastInput = null; if (live != null) live.data="";
	}
	private function loadPool():Void {
		loading = true;
		var started=MetricClock.now(), before=RuntimeInfo.resources();
		poolReferenceBaseline=before.references;
		var owner = new Assets(); pool = owner; owner.tryLoadTimes = 0;
		owner.loadGlb("assets/robot.glb"); owner.loadGlb("assets/robot-dense.glb");
		for (i in 0...20) owner.loadBitmapData("assets/"+AcceptanceWorld.tile(i)+".png");
		owner.loadJson("assets/manifest.json");
		owner.onProgress(value -> { state.data = "固定资源加载："+Math.round(value*100)+"%"; });
		owner.onError(error -> {
			loading=false; owner.stop(); owner.clean(); pool=null;
			poolLoads.push({complete:false,elapsedMs:MetricClock.now()-started,before:before,after:RuntimeInfo.resources(),error:error.error});
			problem("资源加载失败："+error.error);
		});
		owner.onComplete(_ -> {
			loading=false; manifest=owner.getObject("manifest");
			poolLoads.push({complete:true,elapsedMs:MetricClock.now()-started,before:before,after:RuntimeInfo.resources(),cacheEnabled:RequestQueue.enableCache});
			rebuild(); if (world != null) state.data="资源就绪。选择采样、诊断或资源循环；启动时不自动运行验收。";
		});
		owner.start();
	}
	private function rebuild():Float {
		if (pool == null) return 0;
		var started = MetricClock.now(); clearWorld();
		try {
			world = new AcceptanceWorld(pool,cases[selected],diagnostic); holder.addChild(world.layer);
			sampler = new FrameSampler(world); title.data="场景 "+(selected+1)+" / "+cases.length+"："+cases[selected].label;
			verdict.data="功能验收：待人工确认";
		} catch (error:Dynamic) { problem("场景创建失败："+Std.string(error)); }
		return MetricClock.now()-started;
	}
	private function startSampling(soak:Bool):Void {
		diagnostic = false;
		var setup = rebuild(); if (world == null) { suiteRunning = soakRunning = false; return; }
		var meta = world.metadata(); meta.environment = RuntimeInfo.environment(); meta.targets = null; meta.simulationStepSeconds = 1/60;
		currentMetadata=meta;
		recorder.begin(cases[selected],meta,setup,soak ? 600 : 240);
		state.data=soak ? "长跑按每 600 帧记录独立窗口，首个预热 120 帧，后续预热 2 帧。" : "先预热 120 帧，再采集 240 帧；请保持页面前台与窗口尺寸。";
	}
	private function stop():Void {
		suiteRunning=false; soakRunning=false; pendingAdvance=false;
		recorder.stop("用户停止，保留未完成结果");
		if (lifecycle != null && lifecycle.busy) { lifecycle.cancel(); state.data="等待当前资源请求完成并释放。"; }
		else state.data="已停止，结果仍可导出。";
	}
	private function startLifecycle():Void {
		if (busy()) return;
		diagnostic=false; clearWorld();
		if (pool != null) { pool.stop(); pool.clean(); pool=null; }
		var afterPoolRelease=RuntimeInfo.resources();
		var poolRelease:Dynamic={expectedReferences:poolReferenceBaseline,actual:afterPoolRelease,
			returned:afterPoolRelease.references == poolReferenceBaseline};
		state.data="资源循环：交替加载低模与高密度角色，每轮创建并绘制两个实例后释放。";
		lifecycle = new LifecycleRun(holder,function(report) {
			report.poolRelease=poolRelease;
			if (!poolRelease.returned) { report.passed=false; report.errors.push("进入循环前，普通资源池引用未回到其加载前基线"); }
			lifecycleReports.push(report); state.data="资源循环结束："+(report.passed ? "检查通过" : "检查未通过")+"；"+report.reason+"。详细数据见导出报告。";
			haxe.Timer.delay(function() { if (!loading) loadPool(); },0);
		});
		lifecycle.start();
	}
	private function recordVisual(passed:Bool):Void {
		if (busy() || world == null) return;
		var note = diagnostic ? "二维采样状态诊断场景的人工画面确认" : "当前场景的人工画面确认";
		recorder.visual(cases[selected].id,passed,note);
		verdict.data=passed ? "人工画面记录：通过" : "人工画面记录：异常";
		if (contextRestoredAt > 0) recorder.log("上下文恢复后人工确认",passed ? "画面通过" : "画面异常");
	}
	private function update():Void {
		var now = MetricClock.now(), hidden = RuntimeInfo.hidden(), size = RuntimeInfo.sizeKey();
		if (hidden) {
			if (!wasHidden) { recorder.log("页面隐藏","性能采样暂停，回来后重新预热"); wasHidden=true; }
			return;
		}
		if (wasHidden || size != windowKey) {
			recorder.restartWarmup(wasHidden ? "页面重新可见" : "窗口尺寸或 DPR 改变");
			if (recorder.running && currentMetadata != null) currentMetadata.environment=RuntimeInfo.environment();
			if (world != null) sampler = new FrameSampler(world);
			wasHidden=false; windowKey=size;
		}
		if (lifecycle != null && lifecycle.busy) lifecycle.tick(now);
		if (world != null && !contextLost) {
			var input = sampler.read(now);
			if (sampler.issue != null && recorder.running) {
				recorder.stop("回调配对失效："+sampler.issue); suiteRunning=soakRunning=false;
				state.data="当前样本无效，请查看报告："+sampler.issue;
			}
			if (input != null) {
				lastInput=input;
				if (recorder.running) {
					if (recorder.warmupLeft == 1) currentMetadata.targets=sampler.targets();
					if (recorder.add(input)) completedCase();
				}
			}
			if (recorder.running && now-sampler.lastFreshAt > 10000) {
				recorder.stop("10 秒内没有新的完整渲染回调"); suiteRunning=soakRunning=false; state.data="渲染统计未更新，当前案例未完成。";
			}
			world.update(1/60);
		}
		// 让静态场景也执行二维合成；不触发 Scene3D 内容失效。
		heartbeatFrame++; heartbeat.alpha=heartbeatFrame%2 == 0 ? 0.9 : 1;
		if (now-statusMs > 250) { statusMs=now; updateLabels(); }
	}
	private function completedCase():Void {
		if (soakRunning) soakSampledMs += recorder.lastResult.sampledDurationMs;
		if (soakRunning && soakSampledMs < 300000) {
			pendingAdvance=true;
			haxe.Timer.delay(function() {
				if (!pendingAdvance || !soakRunning || world == null) return;
				pendingAdvance=false; var environment=currentMetadata.environment; currentMetadata=world.metadata(); currentMetadata.environment=environment;
				currentMetadata.targets=sampler.targets(); currentMetadata.simulationStepSeconds=1/60;
				recorder.begin(cases[selected],currentMetadata,0,600,0,2);
			},0); return;
		}
		soakRunning=false;
		if (suiteRunning && selected+1 < cases.length) {
			pendingAdvance=true;
			haxe.Timer.delay(function() { if (!pendingAdvance || !suiteRunning) return; pendingAdvance=false; selected++; startSampling(false); },0);
		} else { suiteRunning=false; state.data="采样完成。可记录人工画面结果，或导出 JSON 留作基线。"; }
	}
	private function updateLabels():Void {
		if (lifecycle != null && lifecycle.busy) progress.data="资源循环 "+Std.int(Math.min(20,lifecycle.round+1))+" / 20\n"+lifecycle.state;
		else progress.data=recorder.running ? (recorder.warmupLeft>0 ? "预热剩余："+recorder.warmupLeft : "已采样："+recorder.sampleCount+" / "+recorder.targetSamples) : "已保存 "+recorder.results.length+" 组结果";
		if (!recorder.running && lifecycleReports.length>0 && (lifecycle == null || !lifecycle.busy)) {
			var previous:Dynamic=lifecycleReports[lifecycleReports.length-1];
			progress.data += "\n资源循环："+(previous.passed ? "通过" : "未通过");
		}
		if (lastInput != null) live.data="最近完成帧\n3D CPU："+f(lastInput.renderCpuMs)+" ms\n动画 CPU："+f(lastInput.animationCpuMs)+" ms\n主 / 阴影批次："+lastInput.mainDrawCalls+" / "+lastInput.shadowDrawCalls
			+"\n三角形："+lastInput.mainTriangles+"\n上传："+f((lastInput.mainUploadedBytes+lastInput.shadowUploadedBytes)/1024)+" KiB\n目标估算："+f((lastInput.targetBytes+lastInput.shadowMapBytes)/1048576)+" MiB";
		if (lastInput != null) live.data += "\n状态 CPU："+f(lastInput.stateCpuMs)+" ms；查询 "+lastInput.stateQueryCount
			+"\n轻量 / VAO 场景："+lastInput.stateCompositeOnlyScenes+" / "+lastInput.stateVaoScenes;
		var result:Dynamic = recorder.lastResult;
		if (result != null && result.metrics.frameIntervalMs != null) summary.data="最近一组："+result.caseSpec.id+"\n有效完成："+result.complete+"\n平均观察 FPS："+f(result.meanObservedFps)
			+"\n帧间隔 P50 / P95\n"+f(result.metrics.frameIntervalMs.p50)+" / "+f(result.metrics.frameIntervalMs.p95)+" ms\n3D CPU P95："+f(result.metrics.renderCpuMs.p95)+" ms\n超过 33.3 ms："+result.longFramesOver33ms;
		if (world != null && world.probe != null) state.data="诊断：恢复一致 "+world.probe.verified+" 次，异常 "+world.probe.failures.length
			+" 项；最近点 / 线性覆盖 "+world.probe.nearestFrames+" / "+world.probe.linearFrames+"。画面仍需人工确认。";
	}
	private static function f(value:Null<Float>):String { return value == null || !Math.isFinite(value) ? "不可用" : Std.string(Math.round(value*100)/100); }
	private function problem(message:String):Void {
		if (problems.indexOf(message)<0 && problems.length<30) { problems.push(message); recorder.log("运行错误",message); trace("HXMAKER_ACCEPTANCE_ERROR "+message); }
		recorder.stop(message); suiteRunning=soakRunning=pendingAdvance=false; state.data=message;
	}
	private function exportReport():Void {
		// 导出和环境查询会影响帧间隔，先终止当前采样，避免把导出开销混入有效结果。
		if (recorder.running) recorder.stop("用户导出，当前组未完整采集");
		suiteRunning=soakRunning=pendingAdvance=false;
		var probes = diagnostics.copy();
		if (world != null && world.probe != null) probes.push({caseId:cases[selected].id,verified:world.probe.verified,nearestFrames:world.probe.nearestFrames,linearFrames:world.probe.linearFrames,failures:world.probe.failures.copy()});
		var report = {schemaVersion:1,suiteVersion:"2026-10-16-v2-gl-state",environment:RuntimeInfo.environment(),assetManifest:manifest,
			metricsNote:"3D 耗时为 CPU 墙钟提交时间，不是 GPU 时间；目标附件为估算；JS 堆可能不可用且包含记录器自身分配",
			stateMetricsNote:"状态细分之和为 stateCpuMs；按需快照发生于主通道内部，与通道计时存在重叠，不相加计算整帧。旧报告 stateCpuMs 未覆盖按需纹理快照，跨版本优先比较 renderCpuMs。请求帧率按后端设计不等于严格更新上限。",
			performance:recorder.results,comparisons:comparisons(),recordingInProgress:recorder.running,soakSampledMs:soakSampledMs,manualVisualChecks:recorder.manual,
			samplers:probes,poolLoads:poolLoads,lifecycle:lifecycleReports,lifecycleInProgress:lifecycle != null && lifecycle.busy,events:recorder.events,errors:problems,
			context:{lost:contextLost,restoredAtMs:contextRestoredAt,diagnosticSequence:contextSequence},resources:RuntimeInfo.resources(),
			overallVerdict:"未自动判定",acceptanceNote:"需检查目标平台、所有必需案例及人工画面记录"};
		var json = haxe.Json.stringify(report,null,"  "), filename="hxmaker-3d-baseline-"+Std.string(Date.now().getTime())+".json";
		#if (js && html5)
		var url=js.html.URL.createObjectURL(new js.html.Blob([json],{type:"application/json"}));
		var anchor=js.Browser.document.createAnchorElement(); anchor.href=url; anchor.download=filename;
		js.Browser.document.body.appendChild(anchor); anchor.click(); anchor.remove();
		haxe.Timer.delay(function() { js.html.URL.revokeObjectURL(url); },1000);
		#else
		new openfl.net.FileReference().save(json,filename);
		#end
		state.data="已导出结果；若在采样中导出，该组按未完成保存，不能作为完整基线。";
	}
	private function comparisons():Array<Dynamic> {
		function latest(id:String):Dynamic {
			var found:Dynamic=null;
			for (result in recorder.results) if (result.complete && result.caseSpec.id == id) found=result;
			return found;
		}
		var result:Array<Dynamic>=[];
		for (pair in [["boxes-single","boxes-multi"],["actors-30-single","actors-30-multi"],
			["static-redraw","static-cached"],["dense-shadow-1024","dense-shadow-512"]]) {
			var reference=latest(pair[0]),candidate=latest(pair[1]);
			if (reference == null || candidate == null) continue;
			var sameTargets=haxe.Json.stringify(reference.scene.targets) == haxe.Json.stringify(candidate.scene.targets);
			// 阴影尺寸是该对照的变量，单独比较主场景目标尺寸。
			if (pair[0] == "dense-shadow-1024") sameTargets=reference.scene.targets[0].width == candidate.scene.targets[0].width
				&& reference.scene.targets[0].height == candidate.scene.targets[0].height;
			var before:Float=reference.metrics.renderCpuMs.mean,after:Float=candidate.metrics.renderCpuMs.mean;
			result.push({reference:pair[0],candidate:pair[1],sameTargets:sameTargets,
				renderCpuMeanChangePercent:before>0 ? (after/before-1)*100 : null,
				mainDrawCalls:{reference:reference.metrics.mainDrawCalls.mean,candidate:candidate.metrics.mainDrawCalls.mean},
				frameP95Ms:{reference:reference.metrics.frameIntervalMs.p95,candidate:candidate.metrics.frameIntervalMs.p95},
				note:"仅供同环境对照；目标尺寸、实际阴影状态或可见负载不同需另行解释"});
		}
		return result;
	}
	private function installBrowserEvents():Void {
		#if (js && html5)
		// 独立于 Canvas 的恢复记录入口，二维文字消失时仍可记录异常并导出报告。
		recoveryPanel=js.Browser.document.createDivElement();
		recoveryPanel.style.cssText="display:none;position:fixed;right:12px;bottom:12px;z-index:2147483647;background:#162134;color:white;padding:12px;font:14px sans-serif";
		for (item in [{text:"恢复后画面正常",mode:0},{text:"恢复后画面异常",mode:1},{text:"导出验收报告",mode:2}]) {
			var button=js.Browser.document.createButtonElement(); button.textContent=item.text;
			var mode=item.mode;
			button.addEventListener("click",function(_) {
				if (mode == 2) exportReport();
				else {
					if (mode == 0 && (contextLost || contextRestoredAt == 0)) return;
					recorder.visual("context-restore",mode == 0,"通过独立恢复入口记录的人工画面结果");
					if (mode == 0) recoveryPanel.style.display="none";
				}
			});
			recoveryPanel.appendChild(button);
		}
		js.Browser.document.body.appendChild(recoveryPanel);
		js.Browser.window.addEventListener("error",function(event:js.html.ErrorEvent) { problem(event.message+" ("+event.filename+":"+event.lineno+":"+event.colno+")"); });
		js.Browser.window.addEventListener("unhandledrejection",function(event:Dynamic) { problem("未处理异步错误："+Std.string(Reflect.field(event,"reason"))); });
		var gl:Dynamic=openfl.Lib.current.stage.window.context.webgl;
		if (gl != null) {
			var canvas:js.html.CanvasElement=cast gl.canvas;
			canvas.addEventListener("webglcontextlost",function(event:js.html.Event) {
				event.preventDefault(); contextLost=true; recoveryPanel.style.display="block";
				recorder.stop("上下文丢失，本组不完整"); suiteRunning=soakRunning=pendingAdvance=false;
				recorder.log("上下文丢失","等待恢复事件；恢复事件不代表画面恢复成功");
			});
			canvas.addEventListener("webglcontextrestored",function(_) {
				contextLost=false; contextRestoredAt=MetricClock.now();
				if (world != null) sampler=new FrameSampler(world);
				recorder.log("上下文恢复事件","请人工检查三维角色、二维贴图、文字与遮罩，并记录结果");
				state.data="已收到恢复事件，请检查完整画面并记录通过或异常。";
			});
		}
		#end
	}
	private function loseContext():Void {
		if (busy()) return;
		#if (js && html5)
		var gl:Dynamic=openfl.Lib.current.stage.window.context.webgl;
		if (gl == null) { state.data="当前没有可用的 WebGL 上下文。"; return; }
		var extension:Dynamic=gl.getExtension("WEBGL_lose_context");
		if (extension == null) { recorder.log("能力不足","不支持主动丢失上下文"); state.data="当前设备不支持主动丢失上下文。"; return; }
		var sequence=++contextSequence; contextRestoredAt=0;
		recorder.log("用户触发上下文诊断","1000 ms 后请求恢复"); extension.loseContext();
		haxe.Timer.delay(function() { if (sequence == contextSequence) extension.restoreContext(); },1000);
		haxe.Timer.delay(function() { if (sequence == contextSequence && contextLost) problem("上下文恢复等待超时，尚未验收通过"); },10000);
		#else
		state.data="主动上下文诊断仅提供 HTML5 入口。";
		#end
	}
}
