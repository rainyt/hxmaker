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
}
