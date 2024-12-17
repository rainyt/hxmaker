package hx.events;

/**
 * 鼠标事件
 */
class MouseEvent extends Event {
	/**
	 * 点击事件
	 */
	public inline static var CLICK:String = "click";

	/**
	 * 鼠标按下事件
	 */
	public inline static var MOUSE_DOWN:String = "mouseDown";

	/**
	 * 鼠标移动事件
	 */
	public inline static var MOUSE_MOVE:String = "mouseMove";

	/**
	 * 鼠标抬起事件
	 */
	public inline static var MOUSE_UP:String = "mouseUp";

	/**
	 * 鼠标滚轮事件
	 */
	public inline static var MOUSE_WHEEL:String = "mouseWheel";

	/**
	 * 鼠标进入事件
	 */
	public inline static var MOUSE_OVER:String = "mouseOver";

	/**
	 * 鼠标按下的位置X
	 */
	public var stageX:Float = 0;

	/**
	 * 鼠标按下的位置Y
	 */
	public var stageY:Float = 0;
}
