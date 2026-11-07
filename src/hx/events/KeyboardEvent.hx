package hx.events;

/**
 * 键盘事件
 */
class KeyboardEvent extends Event {
	/**
	 * 按键按下时
	 */
	public static inline var KEY_DOWN:String = "keyDown";

	/**
	 * 按键抬起时
	 */
	public static inline var KEY_UP:String = "keyUp";

	/**
	 * 按键码
	 */
	public var keyCode:Int;

	/**
	 * 是否处于输入法组合输入状态
	 */
	public var isComposing:Bool;

	/**
	 * 是否按下 Ctrl 键
	 */
	public var ctrlKey:Bool;

	/**
	 * 是否按下 Command 键
	 */
	public var metaKey:Bool;

	/**
	 * 是否按下 Alt 键
	 */
	public var altKey:Bool;

	/**
	 * 是否按下 Shift 键
	 */
	public var shiftKey:Bool;

	/**
	 * 转换为字符串表示
	 * @return 键盘事件的字符串描述
	 */
	public override function toString():String {
		return "KeyboardEvent[type=" + type + ", keyCode=" + keyCode + "]";
	}
}
