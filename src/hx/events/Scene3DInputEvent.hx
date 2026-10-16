package hx.events;

import hx.geom.Ray3D;

/** 三维输入适配结果；只在视口接收到有效输入后派发，不另建节点冒泡链。 */
class Scene3DInputEvent extends Event {
	/** 按下和抬起构成轻点时派发，携带按下时的射线与命中快照。 */
	public static inline var SELECT:String = "scene3DSelect";

	/** 超过拖动阈值时派发。 */
	public static inline var DRAG_BEGIN:String = "scene3DDragBegin";

	/** 当前拖动正常释放时派发。 */
	public static inline var DRAG_END:String = "scene3DDragEnd";

	/** 因失焦、移除、禁用或显式取消而解除捕获时派发。 */
	public static inline var CANCEL:String = "scene3DInputCancel";

	/** 指针的 hxmaker 舞台逻辑 X 坐标；选择事件使用按下坐标。 */
	public var stageX(default, null):Float;

	/** 指针的 hxmaker 舞台逻辑 Y 坐标；选择事件使用按下坐标。 */
	public var stageY(default, null):Float;

	/** 触摸编号；鼠标为 -1。 */
	public var pointerId(default, null):Int;

	/** 是否来自触摸输入。 */
	public var isTouch(default, null):Bool;

	/** 选择时按下位置的网格命中快照；空白或非选择事件可为 null。 */
	public var hit(default, null):PickResult3D;

	/** 选择时按下位置的世界射线快照；非选择事件可为 null。 */
	public var ray(default, null):Ray3D;

	/** 取消原因字符串，其他事件通常为 null。 */
	public var reason(default, null):String;

	/** 创建不冒泡的三维交互事件，几何命中对象仍是借用引用。 */
	public function new(type:String, stageX:Float, stageY:Float, pointerId:Int, isTouch:Bool, hit:PickResult3D = null, ray:Ray3D = null, reason:String = null) {
		super(type);
		this.stageX = stageX;
		this.stageY = stageY;
		this.pointerId = pointerId;
		this.isTouch = isTouch;
		this.hit = hit;
		this.ray = ray;
		this.reason = reason;
	}
}
