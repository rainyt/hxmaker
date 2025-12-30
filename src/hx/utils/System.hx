package hx.utils;

import hx.macro.MacroTools;
import haxe.macro.Context;

/**
 * 系统工具类
 */
class System {
	/**
	 * 渲染模式
	 */
	public static var renderMode(get, never):String;

	private static function get_renderMode():String {
		#if openfl
		return openfl.Lib.current.stage.window.context.type;
		#else
		return "default";
		#end
	}

	/**
	 * 定义值
	 */
	public static var defines(get, never):Map<String, String>;

	private static function get_defines():Map<String, String> {
		return MacroTools.getDefines();
	}
}
