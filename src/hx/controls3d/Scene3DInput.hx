package hx.controls3d;

import haxe.Timer;
import hx.display.EventDispatcher;
import hx.display.MeshObject;
import hx.display.Scene3D;
import hx.display.Stage;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.events.TouchEvent;
import hx.render3d.Math3D;

/** 通过 hxmaker 视口事件接入选择、旋转和缩放，显式 dispose 解除监听。 */
class Scene3DInput extends EventDispatcher {
	public var view(default, null):Scene3D;
	public var controller:OrbitCameraController3D;
	public var enabled(get, set):Bool;
	public var isDisposed(default, null):Bool = false;
	public var capturing(default, null):Bool = false;
	public var dragging(default, null):Bool = false;
	public var pointerId(default, null):Int = -1;
	public var dragThreshold:Float = 5;
	public var rotationSensitivity:Float = 0.35;
	public var zoomSensitivity:Float = 0.1;
	public var maxDistance:Null<Float> = null;
	public var filter:MeshObject->Bool;
	private var active:Bool = true;
	private var captureStage:Stage;
	private var touch:Bool = false;
	private var startX:Float = 0;
	private var startY:Float = 0;
	private var lastX:Float = 0;
	private var lastY:Float = 0;
	private var pendingRelease:MouseEvent;
	private var pendingTap:Bool = false;
	private var mouseBlockedUntil:Float = 0;
	private function get_enabled():Bool { return active; }
	private function set_enabled(value:Bool):Bool {
		if (value && isDisposed) throw "三维输入适配已经销毁";
		active = value; if (!value) cancel("disabled"); return value;
	}
	public function new(view:Scene3D, controller:OrbitCameraController3D = null) {
		if (view == null || view.isDisposed) throw "三维输入适配需要有效视口";
		this.view = view; this.controller = controller;
		view.addEventListener(MouseEvent.MOUSE_DOWN,onPress); view.addEventListener(TouchEvent.TOUCH_BEGIN,onPress);
		view.addEventListener(MouseEvent.MOUSE_UP,onRelease); view.addEventListener(TouchEvent.TOUCH_END,onRelease);
		view.addEventListener(MouseEvent.MOUSE_WHEEL,onWheel);
		view.addEventListener(Event.REMOVED_FROM_STAGE,onRemoved); view.addEventListener(Scene3D.DISPOSE,onRemoved);
	}
	private function validateSettings():Void {
		for (value in [dragThreshold,rotationSensitivity,zoomSensitivity]) if (!Math3D.finite(value) || value < 0) throw "三维输入灵敏度必须是非负有限数值";
		if (maxDistance != null && (Math.isNaN(maxDistance) || maxDistance < 0)) throw "拾取距离无效";
	}
	private function onPress(event:MouseEvent):Void {
		if (!active || isDisposed || event.isDefaultPrevented || event.target != view || view.stage == null) return;
		var isTouch = Std.isOfType(event,TouchEvent);
		if (!isTouch && Timer.stamp() < mouseBlockedUntil) return;
		if (capturing) return;
		if (view.stageToViewport(event.stageX,event.stageY) == null) return;
		validateSettings(); clearPending();
		touch = isTouch; pointerId = isTouch ? cast(event,TouchEvent).touchPointID : -1;
		if (touch) mouseBlockedUntil = Timer.stamp()+0.6;
		startX = lastX = event.stageX; startY = lastY = event.stageY; capturing = true; dragging = false;
		captureStage = view.stage; captureStage.addPointerCaptureListener(onCaptured);
		captureStage.addEventListener(Event.DEACTIVATE,onDeactivate); captureStage.addEventListener(Event.RESIZE,onDeactivate);
	}
	private function matches(event:MouseEvent):Bool {
		return Std.isOfType(event,TouchEvent) == touch && (!touch || cast(event,TouchEvent).touchPointID == pointerId);
	}
	private function onCaptured(event:MouseEvent):Void {
		if (!capturing || !matches(event)) return;
		if (!active || isDisposed || view.isDisposed || view.stage != captureStage) { cancel("inactive"); return; }
		if (touch) mouseBlockedUntil = Timer.stamp()+0.6;
		if (!Math3D.finite(event.stageX) || !Math3D.finite(event.stageY)) { cancel("invalidCoordinates"); return; }
		if (event.type == MouseEvent.MOUSE_DOWN || event.type == TouchEvent.TOUCH_BEGIN) cancel("newPress");
		else if (event.type == TouchEvent.TOUCH_CANCEL) cancel("pointerCancel");
		else if (event.type == MouseEvent.MOUSE_MOVE || event.type == TouchEvent.TOUCH_MOVE) {
			validateSettings();
			var dx = event.stageX-startX, dy = event.stageY-startY;
			if (!dragging && dx*dx+dy*dy > dragThreshold*dragThreshold) {
				dragging = true; notify(Scene3DInputEvent.DRAG_BEGIN,event);
			}
			if (!capturing || !active || isDisposed) return;
			if (dragging && usableController()) controller.rotate(-(event.stageX-lastX)*rotationSensitivity,(event.stageY-lastY)*rotationSensitivity);
			lastX = event.stageX; lastY = event.stageY;
		} else if (event.type == MouseEvent.MOUSE_UP || event.type == TouchEvent.TOUCH_END) {
			var movedX = event.stageX-startX, movedY = event.stageY-startY;
			pendingTap = !dragging && movedX*movedX+movedY*movedY <= dragThreshold*dragThreshold;
			pendingRelease = pendingTap ? event : null;
			if (pendingTap) view.addEventListener(Event.UPDATE,clearPending);
			var wasDragging = dragging; capturing = false; dragging = false; releaseStage();
			if (wasDragging) notify(Scene3DInputEvent.DRAG_END,event);
		}
	}
	private function onRelease(event:MouseEvent):Void {
		var select = pendingRelease == event && pendingTap;
		clearPending();
		if (!select || !active || isDisposed || event.isDefaultPrevented || event.target != view) return;
		var ray = view.stageRay(event.stageX,event.stageY);
		if (ray == null) return;
		var hit = view.pick(event.stageX,event.stageY,maxDistance,filter);
		var result = new Scene3DInputEvent(Scene3DInputEvent.SELECT,event.stageX,event.stageY,pointerId,touch,hit,ray);
		result.target = this; dispatchEvent(result);
	}
	private function onWheel(event:MouseEvent):Void {
		if (!active || isDisposed || event.isDefaultPrevented || event.target != view || !usableController()) return;
		validateSettings();
		if (!Math3D.finite(event.delta)) return;
		controller.zoomBy(Math.exp(Math.max(-4,Math.min(4,-event.delta*zoomSensitivity))));
	}
	private function usableController():Bool {
		return controller != null && !controller.isDisposed && controller.enabled && controller.camera == view.camera;
	}
	private function notify(type:String, event:MouseEvent):Void {
		var result = new Scene3DInputEvent(type,event.stageX,event.stageY,pointerId,touch);
		result.target = this; dispatchEvent(result);
	}
	private function onDeactivate(event:Event):Void { cancel(event.type); }
	private function onRemoved(event:Event):Void { if (event.type == Scene3D.DISPOSE) dispose(); else cancel(event.type); }
	private function clearPending(event:Event = null):Void {
		pendingRelease = null; pendingTap = false;
		if (view != null) view.removeEventListener(Event.UPDATE,clearPending);
	}
	private function releaseStage():Void {
		if (captureStage == null) return;
		captureStage.removePointerCaptureListener(onCaptured);
		captureStage.removeEventListener(Event.DEACTIVATE,onDeactivate); captureStage.removeEventListener(Event.RESIZE,onDeactivate);
		captureStage = null;
	}
	/** 后端未转发窗口离开或触摸取消时，宿主可显式调用；不会触发选择。 */
	public function cancel(reason:String = "cancel"):Void {
		var hadCapture = capturing;
		capturing = false; dragging = false; clearPending(); releaseStage();
		if (hadCapture && !isDisposed) {
			var result = new Scene3DInputEvent(Scene3DInputEvent.CANCEL,lastX,lastY,pointerId,touch,null,null,reason);
			result.target = this; dispatchEvent(result);
		}
	}
	public function dispose():Void {
		if (isDisposed) return;
		// 先设失效标记，销毁时不允许取消监听重新启动输入。
		isDisposed = true; active = false; cancel("dispose");
		view.removeEventListener(MouseEvent.MOUSE_DOWN,onPress); view.removeEventListener(TouchEvent.TOUCH_BEGIN,onPress);
		view.removeEventListener(MouseEvent.MOUSE_UP,onRelease); view.removeEventListener(TouchEvent.TOUCH_END,onRelease);
		view.removeEventListener(MouseEvent.MOUSE_WHEEL,onWheel);
		view.removeEventListener(Event.REMOVED_FROM_STAGE,onRemoved); view.removeEventListener(Scene3D.DISPOSE,onRemoved);
		controller = null; view = null; filter = null; removeEventListeners();
	}
}
