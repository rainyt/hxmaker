package hx.utils;

import hx.core.Hxmaker;
import haxe.Timer;

/**
 * 上下文统计信息
 */
class ContextStats {
	private static var __drawcall = 0;
	private static var __vertexCount = 0;
	private static var __fpses:Array<Float> = [];
	private static var __visibleDisplayCounts = 0;
	private static var __cpu:Float = 0;
	private static var __cpuTimer:Float = 0;
	private static var __cpus:Array<Float> = [];
	private static var __memory:Int = 0;
	private static var __spineRenderCount:Int = 0;
	private static var __graphicRenderCount:Int = 0;

	/**
	 * 帧率
	 */
	public static var fps(get, never):Int;

	private static function get_fps():Int {
		if (__fpses.length - 1 == Std.int(__fpses.length / 10) * 10) {
			return __fpses.length - 1;
		}
		return __fpses.length;
	}

	/**
	 * 当前绘制次数调用
	 */
	public static var drawCall(get, never):Int;

	private static function get_drawCall():Int {
		return __drawcall;
	}

	/**
	 * 顶点数量
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
	}

	public static function reset():Void {
		__drawcall = 0;
		__visibleDisplayCounts = 0;
		__vertexCount = 0;
		__spineRenderCount = 0;
		__timeTaskCounts = 0;
		__graphicRenderCount = 0;
		__blendModeFilterDrawCall = 0;
	}

	/**
	 * Spine渲染次数
	 */
	public static var spineRenderCount(get, never):Int;

	private static function get_spineRenderCount():Int {
		return __spineRenderCount;
	}

	/**
	 * 统计Spine渲染次数
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
	 * 计算FPS
	 */
	public static function statsFps():Void {
		var now = Timer.stamp();
		__fpses = __fpses.filter(f -> now - f <= 1);
		__fpses.push(now);
	}

	public static function statsVisibleDisplayCounts():Void {
		__visibleDisplayCounts++;
	}

	/**
	 * CPU使用率
	 */
	public static var cpu(get, never):Float;

	private static function get_cpu():Float {
		return __cpu;
	}

	/**
	 * 帧使用时间
	 */
	public static var frameUsedTime(get, never):Float;

	private static var __frameUsedTime:Float = 0;

	private static function get_frameUsedTime():Float {
		return __frameUsedTime;
	}

	public static function statsCpu():Void {
		var now = Timer.stamp();
		__cpus.push(now - __cpuTimer);
		if (__cpus.length > 180) {
			__cpus.shift();
		}
		var all = 0.;
		for (f in __cpus) {
			all += f;
		}
		__frameUsedTime = all / __cpus.length;
		__cpu = __frameUsedTime / (1 / Hxmaker.engine.frameRate);
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
		return openfl.Lib.current.stage.context3D.totalGPUMemory;
		#else
		return 0;
		#end
	}
}
