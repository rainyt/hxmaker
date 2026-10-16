package hx.controls3d;

import hx.display.Camera3D;
import hx.display.Node3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 以目标世界位置和世界偏移为环绕中心，沿用父类的旋转、缩放和平滑。 */
class FollowCameraController3D extends OrbitCameraController3D {
	public var targetNode(get, set):Node3D;
	public var targetOffset:Vector3D = new Vector3D(0,1.5,0);
	private var node:Node3D;
	private function get_targetNode():Node3D { return node; }
	private function set_targetNode(value:Node3D):Node3D {
		if (isDisposed) throw "跟随控制器已经销毁";
		if (value != null) validateTarget(value);
		node = value; return value;
	}
	public function new(camera:Camera3D, target:Node3D = null) {
		super(camera);
		targetNode = target;
	}
	override public function syncFromCamera():Void {
		if (node != null && !node.isDisposed) updateTarget();
		super.syncFromCamera();
	}
	override public function update(dt:Float):Void {
		if (!Math3D.finite(dt) || dt < 0) throw "相机时间步长必须是非负有限数值";
		if (isDisposed || !enabled || node == null || node.isDisposed) return;
		updateTarget(); super.update(dt);
	}
	override public function snap():Void {
		if (isDisposed || node == null || node.isDisposed) return;
		updateTarget(); super.snap();
	}
	private function validateTarget(value:Node3D):Void {
		if (value.isDisposed) throw "相机跟随目标已经销毁";
		var current = value;
		while (current != null) { if (current == camera) throw "相机不能跟随自身或自身子节点"; current = current.parent; }
		if (camera.scene != null && value.scene != null && camera.scene != value.scene) throw "相机与跟随目标必须处于同一三维场景";
	}
	private function updateTarget():Void {
		validateTarget(node);
		if (targetOffset == null || target == null) throw "跟随偏移与观察点不能为空";
		for (value in [targetOffset.x,targetOffset.y,targetOffset.z]) if (!Math3D.finite(value)) throw "跟随偏移必须是有限数值";
		var position = node.getWorldPosition(); target.setTo(position.x+targetOffset.x,position.y+targetOffset.y,position.z+targetOffset.z);
	}
	override public function dispose():Void { node = null; super.dispose(); }
}
