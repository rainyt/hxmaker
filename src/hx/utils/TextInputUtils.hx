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

	/**
	 * 选区变化时同步到原生输入通道（默认实现为空）
	 */
	public static function syncSelectionToNative(input:InputLabel):Void {}

	/** 文本或输入模式变化时同步原生通道（默认实现为空）。 */
	public static function syncTextToNative(input:InputLabel):Void {}
}
#end
