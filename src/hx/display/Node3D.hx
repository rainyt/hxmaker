package hx.display;

import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 独立三维节点，不参与二维布局；旋转单位为角度。 */
class Node3D extends EventDispatcher {
	public var name:String;
	public var parent(default, null):Node3D;
	public var scene(default, null):Scene3D;
	public var children(get, never):Array<Node3D>;
	public var isDisposed(default, null):Bool = false;
	public var worldVersion(default, null):Int = 0;
	private var __children:Array<Node3D> = [];
	private var __world:Matrix3D = new Matrix3D();
	private var __matrixOverride:Matrix3D;
	private var __worldDirty:Bool = true;
	private var __visible:Bool = true;
	public var visible(get, set):Bool;
	private function get_visible():Bool { return __visible; }
	private function set_visible(value:Bool):Bool { if (__visible != value) { __visible = value; invalidate(); } return value; }
	private var __x:Float = 0;
	public var x(get, set):Float;
	private function get_x():Float { return __x; }
	private function set_x(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__x != value) { __x = value; if (__matrixOverride != null) __matrixOverride.rawData[12] = value; invalidate(); }
		return value;
	}
	private var __y:Float = 0;
	public var y(get, set):Float;
	private function get_y():Float { return __y; }
	private function set_y(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__y != value) { __y = value; if (__matrixOverride != null) __matrixOverride.rawData[13] = value; invalidate(); }
		return value;
	}
	private var __z:Float = 0;
	public var z(get, set):Float;
	private function get_z():Float { return __z; }
	private function set_z(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__z != value) { __z = value; if (__matrixOverride != null) __matrixOverride.rawData[14] = value; invalidate(); }
		return value;
	}
	private var __rotationX:Float = 0;
	public var rotationX(get, set):Float;
	private function get_rotationX():Float { return __rotationX; }
	private function set_rotationX(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__rotationX != value) { __rotationX = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	private var __rotationY:Float = 0;
	public var rotationY(get, set):Float;
	private function get_rotationY():Float { return __rotationY; }
	private function set_rotationY(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__rotationY != value) { __rotationY = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	private var __rotationZ:Float = 0;
	public var rotationZ(get, set):Float;
	private function get_rotationZ():Float { return __rotationZ; }
	private function set_rotationZ(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__rotationZ != value) { __rotationZ = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	private var __scaleX:Float = 1;
	public var scaleX(get, set):Float;
	private function get_scaleX():Float { return __scaleX; }
	private function set_scaleX(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__scaleX != value) { __scaleX = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	private var __scaleY:Float = 1;
	public var scaleY(get, set):Float;
	private function get_scaleY():Float { return __scaleY; }
	private function set_scaleY(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__scaleY != value) { __scaleY = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	private var __scaleZ:Float = 1;
	public var scaleZ(get, set):Float;
	private function get_scaleZ():Float { return __scaleZ; }
	private function set_scaleZ(value:Float):Float {
		if (!Math3D.finite(value)) throw "三维变换必须是有限数值";
		if (__scaleZ != value) { __scaleZ = value; __matrixOverride = null; invalidate(); }
		return value;
	}
	public function new() {}
	private function get_children():Array<Node3D> { return __children.copy(); }
	public function setPosition(x:Float, y:Float, z:Float):Void { this.x = x; this.y = y; this.z = z; }
	public function setScale(x:Float, y:Float, z:Float):Void { scaleX = x; scaleY = y; scaleZ = z; }
	public function addChild<T:Node3D>(child:T):T {
		if (isDisposed || child == null || child.isDisposed) throw "不能挂接空节点或已销毁节点";
		if (child.scene != null && child.scene.root == child) throw "不能重新挂接场景根节点";
		var ancestor:Node3D = this;
		while (ancestor != null) { if (ancestor == child) throw "三维对象树不能包含循环"; ancestor = ancestor.parent; }
		if (child.parent == this) return child;
		child.remove(); child.parent = this; __children.push(child); child.setScene(scene); child.invalidate();
		return child;
	}
	public function removeChild<T:Node3D>(child:T):T {
		if (child != null && __children.remove(child)) {
			if (scene != null) scene.requestRender();
			child.parent = null; child.setScene(null); child.invalidate();
		}
		return child;
	}
	public function remove():Void { if (parent != null) parent.removeChild(this); }
	/** 仅由场景根节点和父子关系变更调用。 */
	@:allow(hx.display.Scene3D)
	private function setScene(value:Scene3D):Void {
		var previous = scene;
		scene = value;
		if (previous != null && previous != value && previous.camera == this) previous.camera = null;
		for (child in __children) child.setScene(value);
	}
	public function invalidate():Void {
		if (isDisposed) return;
		markWorldDirty();
		if (scene != null) scene.requestRender();
	}
	private function markWorldDirty():Void {
		__worldDirty = true;
		for (child in __children) child.markWorldDirty();
	}
	public function getLocalMatrix():Matrix3D {
		return __matrixOverride != null ? __matrixOverride.clone() : Math3D.compose(x, y, z, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);
	}
	/** 保存精确矩阵；后续修改旋转或缩放时恢复使用标量变换。 */
	public function setLocalMatrix(value:Matrix3D):Void {
		if (value == null) throw "三维矩阵不能为空";
		if (value.rawData == null || value.rawData.length != 16) throw "三维矩阵必须包含十六个元素";
		for (v in value.rawData) if (!Math3D.finite(v)) throw "三维矩阵包含无效数值";
		if (Math.abs(value.determinant) < 1e-12 || Math.abs(value.rawData[3]) > 1e-9 || Math.abs(value.rawData[7]) > 1e-9
			|| Math.abs(value.rawData[11]) > 1e-9 || Math.abs(value.rawData[15] - 1) > 1e-9)
			throw "节点矩阵必须是可逆的仿射矩阵，零缩放请通过缩放属性设置";
		var parts = value.decompose();
		__x = value.rawData[12]; __y = value.rawData[13]; __z = value.rawData[14];
		if (parts != null) {
			__rotationX = parts[1].x * 180 / Math.PI; __rotationY = parts[1].y * 180 / Math.PI; __rotationZ = parts[1].z * 180 / Math.PI;
			__scaleX = parts[2].x; __scaleY = parts[2].y; __scaleZ = parts[2].z;
		}
		__matrixOverride = value.clone();
		__matrixOverride.rawData[3] = __matrixOverride.rawData[7] = __matrixOverride.rawData[11] = 0;
		__matrixOverride.rawData[15] = 1; invalidate();
	}
	public function getWorldMatrix():Matrix3D {
		if (__worldDirty) {
			__world = parent == null ? getLocalMatrix() : Math3D.multiply(parent.getWorldMatrix(), getLocalMatrix());
			__worldDirty = false; worldVersion++;
		}
		return __world.clone();
	}
	public function getWorldPosition():Vector3D { return getWorldMatrix().transformVector(new Vector3D()); }
	public function isWorldVisible():Bool { return !isDisposed && visible && (parent == null || parent.isWorldVisible()); }
	public function dispose():Void {
		if (isDisposed) return;
		remove();
		for (child in __children.copy()) child.dispose();
		__children = []; setScene(null); isDisposed = true; removeEventListeners();
	}
}
