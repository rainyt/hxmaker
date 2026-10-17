package;

/** 仅接收已完成渲染的采样；分位数使用排序后的最近秩，不丢弃长帧。 */
class BaselineRecorder {
	public var running(default,null):Bool = false;
	public var warmupLeft(default,null):Int = 0;
	public var sampleCount(default,null):Int = 0;
	public var targetSamples(default,null):Int = 240;
	public var results:Array<Dynamic> = [];
	public var events:Array<Dynamic> = [];
	public var manual:Array<Dynamic> = [];
	public var lastResult:Dynamic;
	private var spec:CaseSpec;
	private var columns:Map<String,Array<Float>> = [];
	private var started:Float;
	private var setupMs:Float;
	private var warmupFrames:Int;
	private var metadata:Dynamic;
	private var wallLimitMs:Float;
	private var durations:Array<Float>;
	private var sampledMs:Float = 0;

	public function new() {}
	public function begin(spec:CaseSpec,metadata:Dynamic,setupMs:Float,samples:Int = 240,minimumMs:Float = 0,warmup:Int = 120):Void {
		this.spec = spec; this.metadata = metadata; this.setupMs = setupMs;
		targetSamples = samples; wallLimitMs = minimumMs; warmupFrames = warmup; warmupLeft = warmupFrames;
		sampleCount = 0; columns = []; durations = []; sampledMs = 0; started = MetricClock.now(); running = true;
	}
	public function restartWarmup(reason:String):Void {
		if (!running) return;
		warmupFrames=120;
		log("采样重新预热",reason+"；丢弃当前窗口未完成的 "+sampleCount+" 个样本");
		warmupLeft = warmupFrames; sampleCount = 0; columns.clear(); durations = [];
		sampledMs = 0; started = MetricClock.now();
	}
	/** 渲染与动画配对上一轮，缓存与堆为读取时的观察值。 */
	public function add(input:Dynamic):Bool {
		if (!running) return false;
		if (warmupLeft > 0) { warmupLeft--; return false; }
		for (key in Reflect.fields(input)) {
			var value:Dynamic = Reflect.field(input,key);
			if (value == null || !Std.isOfType(value,Float) && !Std.isOfType(value,Int)) continue;
			var number:Float = value;
			if (!Math.isFinite(number) || number < 0) continue;
			var values = columns.get(key); if (values == null) { values = []; columns.set(key,values); } values.push(number);
		}
		durations.push(input.frameIntervalMs); sampleCount++; sampledMs += input.frameIntervalMs;
		if (wallLimitMs > 0 ? sampledMs >= wallLimitMs : sampleCount >= targetSamples) { finish(true,"完成"); return true; }
		return false;
	}
	public function stop(reason:String):Void { if (running) finish(false,reason); }
	private function finish(done:Bool,reason:String):Void {
		running = false;
		var metrics:Dynamic = {};
		for (key => values in columns) Reflect.setField(metrics,key,summarize(values));
		var total = 0., longFrames = 0;
		for (value in durations) { total += value; if (value > 1000/30) longFrames++; }
		var frame:Dynamic = Reflect.field(metrics,"frameIntervalMs");
		lastResult = {caseSpec:spec,complete:done,reason:reason,samples:sampleCount,warmupFrames:warmupFrames,setupMs:setupMs,
			wallDurationMs:MetricClock.now()-started,sampledDurationMs:total,meanObservedFps:total > 0 ? sampleCount*1000/total : null,
			longFramesOver33ms:longFrames,metrics:metrics,scene:metadata,
			budget:{targetFps:60,frameBudgetMs:1000/60,p95ToleranceMs:1000/60*1.25,
				p95WithinTolerance:frame == null ? null : frame.p95 <= 1000/60*1.25,
				note:"仅为帧间隔预算参考，完整功能验收需结合人工画面检查；CPU 提交耗时不是 GPU 耗时"}};
		results.push(lastResult);
		trace("HXMAKER_BASELINE_CASE " + haxe.Json.stringify(lastResult));
	}
	public function log(kind:String,message:String):Void { events.push({atMs:MetricClock.now(),kind:kind,message:message}); }
	public function visual(id:String,passed:Bool,note:String):Void {
		manual.push({caseId:id,passed:passed,note:note,atMs:MetricClock.now()});
	}
	public static function summarize(input:Array<Float>):Dynamic {
		if (input.length == 0) return null;
		var values = input.copy(); values.sort(Reflect.compare);
		var sum = 0.; for (value in values) sum += value;
		function rank(p:Float):Float { return values[Std.int(Math.max(0,Math.ceil(p*values.length)-1))]; }
		return {count:values.length,mean:sum/values.length,min:values[0],p50:rank(0.5),p95:rank(0.95),p99:rank(0.99),max:values[values.length-1]};
	}
}
