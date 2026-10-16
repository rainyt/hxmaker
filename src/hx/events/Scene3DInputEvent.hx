package hx.events;

import hx.geom.Ray3D;

/** 三维输入适配结果；只在视口接收到有效输入后派发，不另建节点冒泡链。 */
class Scene3DInputEvent extends Event {
	public static inline var SELECT:String = "scene3DSelect";
	public static inline var DRAG_BEGIN:String = "scene3DDragBegin";
	public static inline var DRAG_END:String = "scene3DDragEnd";
	public static inline var CANCEL:String = "scene3DInputCancel";
	public var stageX(default, null):Float;
	public var stageY(default, null):Float;
	public var pointerId(default, null):Int;
	public var isTouch(default, null):Bool;
	public var hit(default, null):PickResult3D;
	public var ray(default, null):Ray3D;
	public var reason(default, null):String;
	public function new(type:String, stageX:Float, stageY:Float, pointerId:Int, isTouch:Bool,
		hit:PickResult3D = null, ray:Ray3D = null, reason:String = null) {
		super(type); this.stageX = stageX; this.stageY = stageY; this.pointerId = pointerId; this.isTouch = isTouch;
		this.hit = hit; this.ray = ray; this.reason = reason;
	}
}
