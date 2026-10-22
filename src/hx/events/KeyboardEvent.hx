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

	/** 本次按键是否按住 Shift。 */
	public var shiftKey:Bool = false;

	/** 本次按键是否按住 Ctrl。 */
	public var ctrlKey:Bool = false;

	/** 本次按键是否按住 Alt。 */
	public var altKey:Bool = false;

	/** 本次按键是否按住 Command 等系统修饰键。 */
	public var metaKey:Bool = false;

	/** 本次按键是否属于输入法组合过程。 */
	public var isComposing:Bool = false;

	/**
	 * 转换为字符串表示
	 * @return 键盘事件的字符串描述
	 */
	public override function toString():String {
		return "KeyboardEvent[type=" + type + ", keyCode=" + keyCode + "]";
	}
}
