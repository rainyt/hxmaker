package hx.events;

/**
 * 触摸事件类，继承自 Event
 * 用于处理触摸相关的交互事件，包括触摸开始、结束和移动
 */
class TouchEvent extends MouseEvent {
	/**
	 * 触摸开始事件类型
	 * 当用户触摸屏幕时触发
	 */
	public static var TOUCH_BEGIN:String = "touchBegin";

	/**
	 * 触摸结束事件类型
	 * 当用户从屏幕上抬起手指时触发
	 */
	public static var TOUCH_END:String = "touchEnd";

	/**
	 * 触摸移动事件类型
	 * 当用户在屏幕上移动手指时触发
	 */
	public static var TOUCH_MOVE:String = "touchMove";

	/**
	 * 触摸点ID
	 * 用于标识不同的触摸点，支持多点触控
	 * 默认值为-1，表示未定义的触摸点
	 */
	public var touchPointID:Int = -1;

	/**
	 * 触摸点X坐标
	 */
	public var touchX:Float = 0;

	/**
	 * 触摸点Y坐标
	 */
	public var touchY:Float = 0;
}
