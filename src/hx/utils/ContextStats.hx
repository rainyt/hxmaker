package hx.utils;

import haxe.Timer;

class ContextStats {
	private static var __drawcall = 0;
	private static var __vertexCount = 0;
	private static var __fpses:Array<Float> = [];
	private static var __visibleDisplayCounts = 0;
	private static var __cpu:Float = 0;
	private static var __cpuTimer:Float = 0;
	private static var __cpus:Array<Float> = [];

	/**
	 * 帧率
	 */
	public static var fps(get, never):Int;

	private static function get_fps():Int {
		return __fpses.length - 1;
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
	}

	public static function statsDrawCall():Void {
		__drawcall++;
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

	public static function statsCpu():Void {
		var now = Timer.stamp();
		__cpus.push((now - __cpuTimer) / 0.0166);
		if (__cpus.length > 60) {
			__cpus.shift();
		}
		var all = 0.;
		for (f in __cpus) {
			all += f;
		}
		__cpu = all / __cpus.length;
	}
}
