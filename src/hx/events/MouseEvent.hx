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
	 * 鼠标双击事件
	 */
	public inline static var DOUBLE_CLICK:String = "doubleClick";

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
	 * 鼠标离开事件
	 */
	public inline static var MOUSE_OUT:String = "mouseOut";

	/**
	 * 鼠标长按事件，按下0.5秒会触发持续性的鼠标事件
	 */
	public inline static var MOUSE_LONG_CLICK:String = "mouseLongClick";

	/**
	 * 鼠标按下的位置X
	 */
	public var stageX:Float = 0;

	/**
	 * 鼠标按下的位置Y
	 */
	public var stageY:Float = 0;

	/**
	 * 
	 * 指示用户旋转的每个单位应滚动多少行
	 * 鼠标滚轮。正的增量值表示向上滚动；一
	 * 负值表示向下滚动。典型值为1至3，但
	 * 更快的旋转可能会产生更大的值。此设置取决于
	 * 设备和操作系统，通常可由用户配置。这个
	 * 属性仅适用于`MouseEvent.mouseWheel`事件。
	 */
	public var delta:Float = 0;
}
