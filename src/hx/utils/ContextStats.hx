package hx.utils;

import haxe.Timer;

class ContextStats {
	private static var __drawcall = 0;
	private static var __vertexCount = 0;
	private static var __fpses:Array<Float> = [];

	/**
	 * 帧率
	 */
	public static var fps(get, never):Int;

	private static function get_fps():Int {
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

	private static function get_vertexCount():Int {
		return __vertexCount;
	}

	public static function reset():Void {
		__drawcall = 0;
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
		__fpses = __fpses.filter(f -> now - f < 1);
		__fpses.push(now);
	}
}
