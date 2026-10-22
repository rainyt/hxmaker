package hx.utils;

import hx.core.Hxmaker;
import haxe.Timer;

/**
 * 上下文统计信息
 */
class ContextStats {
	private static var __drawcall = 0;
	private static var __vertexCount = 0;
	private static var __visibleDisplayCounts = 0;
	private static var __cpu:Float = 0;
	private static var __cpuTimer:Float = 0;
	private static var __cpus:Array<Float> = [];
	private static var __cpuIndex:Int = 0;
	private static var __cpuSum:Float = 0;
	private static var __memory:Int = 0;
	private static var __memoryAvailable:Bool = false;
	private static var __spineRenderCount:Int = 0;
	private static var __graphicRenderCount:Int = 0;
	private static var __frameActive:Bool = false;
	private static var __frameId:Int = 0;
	private static var __lastFrameStart:Float = -1;
	private static var __targetFrameRate:Int = 0;
	private static var __spineBaseline:Int = 0;
	private static var __timerBaseline:Int = 0;
	private static var __frameSpineUpdates:Int = 0;
	private static var __frameTimerTasks:Int = 0;
	private static var __pendingFrame:ContextStatsFrame;

	/** 最近一秒的有界采样；高于每秒 600 帧时只保留最近 600 帧。 */
	private static inline var SAMPLE_CAPACITY:Int = 600;
	private static var __sampleTimes:Array<Float> = [];
	private static var __sampleIntervals:Array<Float> = [];
	private static var __sampleUsedTimes:Array<Float> = [];
	private static var __sampleHead:Int = 0;
	private static var __sampleCount:Int = 0;
	private static var __intervalSum:Float = 0;
	private static var __usedTimeSum:Float = 0;

	/** 下一帧开始时发布上一帧快照，收齐延迟渲染计数；发布后不再修改。 */
	public static var completedFrame(default, null):ContextStatsFrame;

	/**
	 * 最近采样窗口的平均帧率；启动时按实际采样时长计算。
	 */
	public static var fps(get, never):Int;

	private static function get_fps():Int {
		__pruneSamples(Timer.stamp());
		return __intervalSum > 0 ? Math.round(__sampleCount / __intervalSum) : 0;
	}

	/**
	 * 当前绘制次数调用
	 */
	public static var drawCall(get, never):Int;

	private static function get_drawCall():Int {
		return __drawcall;
	}

	/**
	 * 提交的索引顶点数量，不是去重后的几何顶点数量。
	 */
	public static var vertexCount(get, never):Int;

	/**
	 * 可见显示对象数量
	 */
	public static var visibleDisplayCounts(get, never):Int;

	private static function get_visibleDisplayCounts():Int {
		return __visibleDisplayCounts;
	}

	private static function get_vertexCount():Int {
		return __vertexCount;
	}

	public static function statsCpuStart():Void {
		__cpuTimer = Timer.stamp();
		var interval = __startInterval(__cpuTimer);
		if (__pendingFrame != null) {
			// OpenFL 的三维回调可能晚于 statsCpu，在下一轮更新前收齐绘制计数。
			// 帧间隔与上一轮耗时配对，当前更新即可看到刚发生的长帧。
			__pendingFrame.interval = interval;
			__pendingFrame.drawCall = __drawcall;
			__pendingFrame.vertexCount = __vertexCount;
			__pendingFrame.visibleDisplayCounts = __visibleDisplayCounts;
			__pendingFrame.graphicRenderCount = __graphicRenderCount;
			__pendingFrame.blendModeFilterDrawCall = __blendModeFilterDrawCall;
			__appendSample(__cpuTimer, interval, __pendingFrame.usedTime);
			completedFrame = __pendingFrame;
			__pendingFrame = null;
		}
		__frameSpineUpdates = 0;
		__frameTimerTasks = 0;
		__spineBaseline = __spineRenderCount;
		__timerBaseline = __timeTaskCounts;
		__frameActive = true;
	}

	public static function reset():Void {
		// 兼容后端在更新之后、渲染之前重置计数的顺序，保留本帧更新量。
		if (__frameActive) {
			__frameSpineUpdates += __spineRenderCount - __spineBaseline;
			__frameTimerTasks += __timeTaskCounts - __timerBaseline;
			__spineBaseline = __timerBaseline = 0;
		}
		__drawcall = 0;
		__visibleDisplayCounts = 0;
		__vertexCount = 0;
		__spineRenderCount = 0;
		__timeTaskCounts = 0;
		__graphicRenderCount = 0;
		__blendModeFilterDrawCall = 0;
	}

	/**
	 * Spine 骨架更新次数；保留旧属性名称以兼容已有代码。
	 */
	public static var spineRenderCount(get, never):Int;

	private static function get_spineRenderCount():Int {
		return __spineRenderCount;
	}

	/**
	 * 统计 Spine 骨架更新次数
	 */
	public static function statsSpineRenderCount():Void {
		__spineRenderCount++;
	}

	public static function statsDrawCall(counts:Int = 1):Void {
		__drawcall += counts;
	}

	public static function statsVertexCount(count:Int):Void {
		__vertexCount += count;
	}

	/**
	 * 帧率采样入口；使用引擎计时入口时由 statsCpu 统一提交，避免重复采样。
	 */
	public static function statsFps():Void {
		if (__frameActive) return;
		var now = Timer.stamp();
		__appendSample(now, __startInterval(now), 0);
	}

	public static function statsVisibleDisplayCounts():Void {
		__visibleDisplayCounts++;
	}

	/**
	 * 引擎平均耗时占目标帧预算的比例，不是系统 CPU 使用率。
	 */
	public static var cpu(get, never):Float;

	private static function get_cpu():Float {
		return __cpu;
	}

	/**
	 * 最近 180 次引擎计时的平均耗时（秒）；保留旧接口。
	 */
	public static var frameUsedTime(get, never):Float;

	private static var __frameUsedTime:Float = 0;

	private static function get_frameUsedTime():Float {
		return __frameUsedTime;
	}

	public static function statsCpu():Void {
		if (!__frameActive) return;
		var now = Timer.stamp();
		var usedTime = now - __cpuTimer;
		if (!Math.isFinite(usedTime) || usedTime < 0) {
			resetTiming();
			return;
		}
		if (__cpus.length < 180) {
			__cpus.push(usedTime);
		} else {
			__cpuSum -= __cpus[__cpuIndex];
			__cpus[__cpuIndex] = usedTime;
			__cpuIndex = (__cpuIndex + 1) % 180;
		}
		__cpuSum += usedTime;
		__frameUsedTime = __cpuSum / __cpus.length;
		__cpu = __frameUsedTime * __targetFrameRate;
		var frame = new ContextStatsFrame();
		frame.id = ++__frameId;
		frame.frameRate = __targetFrameRate;
		frame.usedTime = usedTime;
		frame.spineUpdateCount = __frameSpineUpdates + __spineRenderCount - __spineBaseline;
		frame.timerTaskCount = __frameTimerTasks + __timeTaskCounts - __timerBaseline;
		__pendingFrame = frame;
		__frameActive = false;
	}

	/** 暂停恢复或目标帧率变化后重新采样；不把停留后台的时间当作卡顿。 */
	public static function resetTiming():Void {
		__lastFrameStart = -1;
		__frameActive = false;
		__sampleHead = __sampleCount = 0;
		__intervalSum = __usedTimeSum = 0;
		__cpus = [];
		__cpuIndex = 0;
		__cpuSum = __frameUsedTime = __cpu = 0;
		completedFrame = null;
		__pendingFrame = null;
	}

	private static function __startInterval(now:Float):Float {
		var rate = Hxmaker.engine == null ? 0 : Hxmaker.engine.frameRate;
		if (rate < 0) rate = 0;
		if (rate != __targetFrameRate) {
			resetTiming();
			__targetFrameRate = rate;
		}
		var interval = __lastFrameStart < 0 ? 0 : now - __lastFrameStart;
		__lastFrameStart = now;
		return interval;
	}

	private static function __removeSample():Void {
		__intervalSum -= __sampleIntervals[__sampleHead];
		__usedTimeSum -= __sampleUsedTimes[__sampleHead];
		__sampleHead = (__sampleHead + 1) % SAMPLE_CAPACITY;
		__sampleCount--;
		if (__sampleCount == 0) __intervalSum = __usedTimeSum = 0;
	}

	private static function __pruneSamples(now:Float):Void {
		while (__sampleCount > 0 && now - __sampleTimes[__sampleHead] >= 1) __removeSample();
	}

	private static function __appendSample(now:Float, interval:Float, usedTime:Float):Void {
		__pruneSamples(now);
		if (!Math.isFinite(interval) || interval <= 0) return;
		if (__sampleCount == SAMPLE_CAPACITY) __removeSample();
		var index = (__sampleHead + __sampleCount) % SAMPLE_CAPACITY;
		__sampleTimes[index] = now;
		__sampleIntervals[index] = interval;
		__sampleUsedTimes[index] = usedTime;
		__intervalSum += interval;
		__usedTimeSum += usedTime;
		__sampleCount++;
	}

	/** 仅在面板刷新时计算分位数；逐帧采集不排序、不遍历整个窗口。 */
	public static function getTiming():ContextStatsTiming {
		__pruneSamples(Timer.stamp());
		var intervals:Array<Float> = [];
		var maxUsedTime = 0.;
		var overBudgetCount = 0;
		var budget = __targetFrameRate > 0 ? 1. / __targetFrameRate : 0;
		for (i in 0...__sampleCount) {
			var index = (__sampleHead + i) % SAMPLE_CAPACITY;
			var interval = __sampleIntervals[index];
			intervals.push(interval);
			maxUsedTime = Math.max(maxUsedTime, __sampleUsedTimes[index]);
			// 留出 10% 的调度误差，避免把正常的帧调度抖动全部计为超预算。
			if (budget > 0 && interval > budget * 1.1) overBudgetCount++;
		}
		intervals.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
		return {
			frameCount: __sampleCount,
			fps: __intervalSum > 0 ? __sampleCount / __intervalSum : 0,
			budgetMs: budget * 1000,
			averageMs: __sampleCount > 0 ? __intervalSum / __sampleCount * 1000 : 0,
			p95Ms: __sampleCount > 0 ? intervals[Std.int(Math.ceil(__sampleCount * 0.95)) - 1] * 1000 : 0,
			maxMs: __sampleCount > 0 ? intervals[__sampleCount - 1] * 1000 : 0,
			averageUsedMs: __sampleCount > 0 ? __usedTimeSum / __sampleCount * 1000 : 0,
			maxUsedMs: maxUsedTime * 1000,
			overBudgetCount: overBudgetCount
		};
	}

	/**
	 * 获得内存值
	 */
	public static var memory(get, never):Int;

	private static function get_memory():Int {
		return __memory;
	}

	/**
	 * 统计内存使用情况
	 * @param memory 
	 */
	public static function statsMemory(memory:Int):Void {
		__memory = memory;
		// 旧后端以 0 表示未支持或尚未取得内存数据，不能将其展示为真实的零占用。
		__memoryAvailable = memory > 0;
	}

	/** 是否已取得有效的运行时堆内存数据；不代表应用全部内存。 */
	public static var memoryAvailable(get, never):Bool;

	private static function get_memoryAvailable():Bool {
		return __memoryAvailable;
	}

	private static var __timeTaskCounts:Int = 0;

	public static var timerTaskCount(get, never):Int;

	private static function get_timerTaskCount():Int {
		return __timeTaskCounts;
	}

	/**
	 * 统计时间任务数量
	 */
	public static function statsTimeTaskCount():Void {
		__timeTaskCounts++;
	}

	/**
	 * 统计图形渲染次数
	 */
	public static function statsGraphicRenderCount():Void {
		__graphicRenderCount++;
	}

	/**
	 * 图形渲染次数
	 */
	public static var graphicRenderCount(get, never):Int;

	private static function get_graphicRenderCount():Int {
		return __graphicRenderCount;
	}

	public static var blendModeFilterDrawCall(get, never):Int;

	private static var __blendModeFilterDrawCall:Int = 0;

	private static function get_blendModeFilterDrawCall():Int {
		return __blendModeFilterDrawCall;
	}

	/**
	 * 统计混合模式滤镜绘制次数
	 */
	public static function statsBlendModeFilterDrawCall():Void {
		__blendModeFilterDrawCall++;
	}

	/**
	 * GPU内存使用量
	 */
	public static var gpuMemory(get, never):Int;

	private static function get_gpuMemory():Int {
		#if openfl
		var current = openfl.Lib.current;
		return current != null && current.stage != null && current.stage.context3D != null ? current.stage.context3D.totalGPUMemory : 0;
		#else
		return 0;
		#end
	}

	/**
	 * 资源总引用计数（由 RequestQueue 更新）
	 */
	public static var totalRefCount:Int = 0;

	/**
	 * 缓存资源总数（由 RequestQueue 更新）
	 */
	public static var totalCacheCount:Int = 0;
}

/** 最近一秒（最多 600 帧）的统计摘要，所有耗时单位为毫秒。 */
typedef ContextStatsTiming = {
	var frameCount:Int;
	var fps:Float;
	var budgetMs:Float;
	var averageMs:Float;
	var p95Ms:Float;
	var maxMs:Float;
	var averageUsedMs:Float;
	var maxUsedMs:Float;
	/** 帧间隔超过目标帧预算 110% 的样本数。 */
	var overBudgetCount:Int;
}
