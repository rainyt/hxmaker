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

	/**
	 * 判断环境是否为电脑
	 * @return Bool
	 */
	public static var isPc(get, never):Bool;

	private static function get_isPc():Bool {
		#if (android || ios || minigame)
		return false;
		#elseif html5
		var userAgent = js.Browser.navigator.userAgent;
		var agents = [
			  "Android",        "iPhone",
			"SymbianOS", "Windows Phone",
			     "iPad",          "iPod"
		];
		for (tag in agents) {
			if (userAgent.indexOf(tag) != -1)
				return false;
		}
		return true;
		#else
		return true;
		#end
	}

	/**
	 * 复制文本到剪贴板
	 * @param text 文本
	 */
	public static function copy(text:String):Void {
		#if wechat_zygame_dom
		if (Wx.setClipboardData != null) {
			Wx.setClipboardData({
				data: text,
				success: (res) -> {
					trace("复制成功");
				},
				fail: (res) -> {
					trace("复制失败：", res);
				}
			});
		}
		#elseif sxk_game_sdk
		v4.NativeApi.copyText(text);
		#end
	}
}
