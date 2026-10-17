package app;

/** 仅保存数值与文本的诊断记录，不持有场景、模型或 Assets。 */
class SampleAudit {
	public var flowsCreated:Int = 0;
	public var flowsDisposed:Int = 0;
	public var sessionsCreated:Int = 0;
	public var sessionsDisposed:Int = 0;
	public var loadsInFlight:Int = 0;
	public var lateResults:Int = 0;
	public var worldsCreated:Int = 0;
	public var worldsDisposed:Int = 0;
	public var simulationUpdates:Int = 0;
	public var animationUpdates:Int = 0;
	public var cyclesCompleted:Int = 0;
	public var injectedFailures:Int = 0;
	private var messages:Array<String> = [];
	private var releases:Array<Dynamic> = [];
	private var failures:Array<String> = [];
	private var renderTimes:Array<Float> = [];
	private var lastRender:Dynamic;
	public function new() {}
	public function log(message:String):Void { messages.push(message); if (messages.length > 80) messages.shift(); }
	public function fail(message:String):Void { failures.push(message); if (failures.length > 30) failures.shift(); log("错误："+message); }
	public function release(value:Dynamic):Void { releases.push(value); if (releases.length > 30) releases.shift(); }
	public function render(cpuMs:Float, value:Dynamic):Void {
		if (!Math.isFinite(cpuMs) || cpuMs < 0) return;
		renderTimes.push(cpuMs); if (renderTimes.length > 300) renderTimes.shift(); lastRender = value;
	}
	public function summary():String {
		return "流程 "+(flowsCreated-flowsDisposed)+"　会话 "+(sessionsCreated-sessionsDisposed)+"　在途 "+loadsInFlight
			+"　场景 "+(worldsCreated-worldsDisposed)+"　迟到清理 "+lateResults+"　循环完成 "+cyclesCompleted;
	}
	public function snapshot():Dynamic {
		var times = renderTimes.copy(), sum = 0.; for (value in times) sum += value;
		times.sort(function(a:Float,b:Float):Int { return a < b ? -1 : a > b ? 1 : 0; });
		return {
			version:1, scope:"interactive-character", visualVerdict:"未自动判定", performanceScope:"最近至多 300 个观测到的新 renderId，跨场景观察值，不是固定性能基线",
			flows:{created:flowsCreated,disposed:flowsDisposed}, sessions:{created:sessionsCreated,disposed:sessionsDisposed,inFlight:loadsInFlight,lateResults:lateResults},
			worlds:{created:worldsCreated,disposed:worldsDisposed}, updates:{simulation:simulationUpdates,animationCalls:animationUpdates}, cyclesCompleted:cyclesCompleted,injectedFailures:injectedFailures,
			render:{samples:times.length,cpuMeanMs:times.length == 0 ? null : sum/times.length,cpuP95Ms:times.length == 0 ? null : times[Std.int(Math.ceil(times.length*0.95))-1],last:lastRender},
			releases:releases.copy(), errors:failures.copy(), events:messages.copy()
		};
	}
}
