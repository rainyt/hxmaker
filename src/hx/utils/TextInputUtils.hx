package hx.utils;

#if wechat
typedef TextInputUtils = hx.utils.inputs.WechatTextInputUtils;
#elseif html5
typedef TextInputUtils = hx.utils.inputs.HTML5TextInputUtils;
#else
import hx.display.InputLabel;

class TextInputUtils {
	/**
	 * 当前焦点输入组件
	 */
	public static var input:InputLabel;

	public static function openInput(input:InputLabel):Void {}

	public static function closeInput(label:InputLabel):Void {}
}
#end
