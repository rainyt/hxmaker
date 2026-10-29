package hx.display3d;

import hx.display.EventDispatcher;
import hx.display.Scene3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 独立三维节点，不参与二维布局；旋转单位为角度。 */
class Node3D extends EventDispatcher {
	/** 业务名称，不要求唯一。 */
	public var name:String;
	private static var nextInstanceId:Int = 0;
	/** 节点生命周期内稳定的标识，设备恢复不会改变缓存分组顺序。 */
	public var instanceId(default, null):Int;

	/** 父三维节点；根节点或已移除节点为 null。 */
	public var parent(default, null):Node3D;

	/** 当前所属三维视口，由节点树挂接关系维护。 */
	public var scene(default, null):Scene3D;

	/** 直接子节点列表副本；修改关系请使用 addChild/removeChild。 */
	public var children(get, never):Array<Node3D>;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 世界矩阵重新求值次数，用于碰撞与渲染缓存检测。 */
	public var worldVersion(default, null):Int = 0;

	private var __children:Array<Node3D> = [];
	private var __world:Matrix3D = new Matrix3D();
	private var __matrixOverride:Matrix3D;
	private var __worldDirty:Bool = true;
	private var __visible:Bool = true;

	/** 本节点的局部可见性；祖先隐藏也会使世界可见性为 false。 */
	public var visible(get, set):Bool;

	private function get_visible():Bool {
		return __visible;
	}

	private function set_visible(value:Bool):Bool {
		if (__visible != value) {
			__visible = value;
			invalidate();
		}
		return value;
	}

	private var __x:Float = 0;

	/** 父节点局部 X 平移，必须为有限数值。 */
	public var x(get, set):Float;

	private function get_x():Float {
		return __x;
	}

	private function set_x(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__x != value) {
			__x = value;
			if (__matrixOverride != null)
				__matrixOverride.rawData[12] = value;
			invalidate();
		}
		return value;
	}

	private var __y:Float = 0;

	/** 父节点局部 Y 平移，必须为有限数值。 */
	public var y(get, set):Float;

	private function get_y():Float {
		return __y;
	}

	private function set_y(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__y != value) {
			__y = value;
			if (__matrixOverride != null)
				__matrixOverride.rawData[13] = value;
			invalidate();
		}
		return value;
	}

	private var __z:Float = 0;

	/** 父节点局部 Z 平移，必须为有限数值。 */
	public var z(get, set):Float;

	private function get_z():Float {
		return __z;
	}

	private function set_z(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__z != value) {
			__z = value;
			if (__matrixOverride != null)
				__matrixOverride.rawData[14] = value;
			invalidate();
		}
		return value;
	}

	private var __rotationX:Float = 0;

	/** 局部 X 轴欧拉旋转角，单位为度。 */
	public var rotationX(get, set):Float;

	private function get_rotationX():Float {
		return __rotationX;
	}

	private function set_rotationX(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__rotationX != value) {
			__rotationX = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	private var __rotationY:Float = 0;

	/** 局部 Y 轴欧拉旋转角，单位为度。 */
	public var rotationY(get, set):Float;

	private function get_rotationY():Float {
		return __rotationY;
	}

	private function set_rotationY(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__rotationY != value) {
			__rotationY = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	private var __rotationZ:Float = 0;

	/** 局部 Z 轴欧拉旋转角，单位为度。 */
	public var rotationZ(get, set):Float;

	private function get_rotationZ():Float {
		return __rotationZ;
	}

	private function set_rotationZ(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__rotationZ != value) {
			__rotationZ = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	private var __scaleX:Float = 1;

	/** 局部 X 缩放，可为负或零；零缩放的退化网格跳过绘制与拾取。 */
	public var scaleX(get, set):Float;

	private function get_scaleX():Float {
		return __scaleX;
	}

	private function set_scaleX(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__scaleX != value) {
			__scaleX = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	private var __scaleY:Float = 1;

	/** 局部 Y 缩放，可为负或零。 */
	public var scaleY(get, set):Float;

	private function get_scaleY():Float {
		return __scaleY;
	}

	private function set_scaleY(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__scaleY != value) {
			__scaleY = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	private var __scaleZ:Float = 1;

	/** 局部 Z 缩放，可为负或零。 */
	public var scaleZ(get, set):Float;

	private function get_scaleZ():Float {
		return __scaleZ;
	}

	private function set_scaleZ(value:Float):Float {
		if (!Math3D.finite(value))
			throw "三维变换必须是有限数值";
		if (__scaleZ != value) {
			__scaleZ = value;
			__matrixOverride = null;
			invalidate();
		}
		return value;
	}

	/** 创建无父节点的三维节点，不加入二维显示树。 */
	public function new() {
		#if hxmaker_unity
		super();
		#end
		instanceId = nextInstanceId++;
	}

	private function get_children():Array<Node3D> {
		return __children.copy();
	}

	/** 设置父节点局部 X/Y/Z 平移，单位为局部世界单位。 */
	public function setPosition(x:Float, y:Float, z:Float):Void {
		this.x = x;
		this.y = y;
		this.z = z;
	}

	/** 同时设置三个局部缩放分量。 */
	public function setScale(x:Float, y:Float, z:Float):Void {
		scaleX = x;
		scaleY = y;
		scaleZ = z;
	}

	/** 接管子节点的树关系，自动从原父节点移除；禁止循环和重新挂接场景根。 */
	public function addChild<T:Node3D>(child:T):T {
		if (isDisposed || child == null || child.isDisposed)
			throw "不能挂接空节点或已销毁节点";
		if (child.scene != null && child.scene.root == child)
			throw "不能重新挂接场景根节点";
		var ancestor:Node3D = this;
		while (ancestor != null) {
			if (ancestor == child)
				throw "三维对象树不能包含循环";
			ancestor = ancestor.parent;
		}
		if (child.parent == this)
			return child;
		child.remove();
		child.parent = this;
		__children.push(child);
		child.setScene(scene);
		child.invalidate();
		return child;
	}

	/** 解除直接子节点关系并返回该节点，不销毁它。 */
	public function removeChild<T:Node3D>(child:T):T {
		if (child != null && __children.remove(child)) {
			if (scene != null)
				scene.requestRender();
			child.parent = null;
			child.setScene(null);
			child.invalidate();
		}
		return child;
	}

	/** 从父节点移除自身，不销毁自身或子树。 */
	public function remove():Void {
		if (parent != null)
			parent.removeChild(this);
	}

	/** 仅由场景根节点和父子关系变更调用。 */
	@:allow(hx.display.Scene3D)
	private function setScene(value:Scene3D):Void {
		var previous = scene;
		scene = value;
		if (previous != null && previous != value && previous.camera == this)
			previous.camera = null;
		if (previous != null && previous != value && previous.light == this)
			previous.light = null;
		for (child in __children)
			child.setScene(value);
	}

	/** 使本节点及后代世界矩阵失效，并请求所属场景重绘。 */
	public function invalidate():Void {
		if (isDisposed)
			return;
		markWorldDirty();
		if (scene != null)
			scene.requestRender();
	}

	private function markWorldDirty():Void {
		__worldDirty = true;
		for (child in __children)
			child.markWorldDirty();
	}

	/** 返回局部变换矩阵副本，包含精确矩阵覆盖或当前 TRS。 */
	public function getLocalMatrix():Matrix3D {
		return __matrixOverride != null ? __matrixOverride.clone() : Math3D.compose(x, y, z, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);
	}

	/** 保存精确矩阵；后续修改旋转或缩放时恢复使用标量变换。 */
	public function setLocalMatrix(value:Matrix3D):Void {
		if (value == null)
			throw "三维矩阵不能为空";
		if (value.rawData == null || value.rawData.length != 16)
			throw "三维矩阵必须包含十六个元素";
		for (v in value.rawData)
			if (!Math3D.finite(v))
				throw "三维矩阵包含无效数值";
		if (Math.abs(value.determinant) < 1e-12 || Math.abs(value.rawData[3]) > 1e-9 || Math.abs(value.rawData[7]) > 1e-9
			|| Math.abs(value.rawData[11]) > 1e-9 || Math.abs(value.rawData[15] - 1) > 1e-9)
			throw "节点矩阵必须是可逆的仿射矩阵，零缩放请通过缩放属性设置";
		var parts = value.decompose();
		__x = value.rawData[12];
		__y = value.rawData[13];
		__z = value.rawData[14];
		if (parts != null) {
			__rotationX = parts[1].x * 180 / Math.PI;
			__rotationY = parts[1].y * 180 / Math.PI;
			__rotationZ = parts[1].z * 180 / Math.PI;
			__scaleX = parts[2].x;
			__scaleY = parts[2].y;
			__scaleZ = parts[2].z;
		}
		__matrixOverride = value.clone();
		__matrixOverride.rawData[3] = __matrixOverride.rawData[7] = __matrixOverride.rawData[11] = 0;
		__matrixOverride.rawData[15] = 1;
		invalidate();
	}

	/** 动画混合可能跨越零缩放；保留精确姿态，退化网格由渲染与拾取跳过。 */
	@:allow(hx.display3d.Model3D)
	private function setAnimationTRS(translation:Array<Float>, rotation:Array<Float>, scale:Array<Float>):Void {
		var matrix = Math3D.fromTRS(translation, rotation, scale);
		for (value in matrix.rawData)
			if (!Math3D.finite(value))
				throw "动画姿态包含无效数值";
		// 已知精确 TRS，无需分解含负缩放或零缩放的矩阵，也避免临时矩阵和向量分配。
		var qx = rotation[0],
			qy = rotation[1],
			qz = rotation[2],
			qw = rotation[3];
		var r2 = Math.max(-1, Math.min(1, 2 * (qx * qz - qy * qw))),
			degrees = 180 / Math.PI;
		__x = translation[0];
		__y = translation[1];
		__z = translation[2];
		__rotationY = Math.asin(-r2) * degrees;
		if (Math.abs(r2) < 1 - 1e-12) {
			__rotationX = Math.atan2(2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)) * degrees;
			__rotationZ = Math.atan2(2 * (qx * qy + qz * qw), 1 - 2 * (qy * qy + qz * qz)) * degrees;
		} else {
			__rotationX = Math.atan2((r2 < 0 ? 1 : -1) * 2 * (qx * qy - qz * qw), 1 - 2 * (qx * qx + qz * qz)) * degrees;
			__rotationZ = 0;
		}
		__scaleX = scale[0];
		__scaleY = scale[1];
		__scaleZ = scale[2];
		__matrixOverride = matrix;
		invalidate();
	}

	/** 惰性计算并返回世界矩阵副本，不暴露内部缓存。 */
	public function getWorldMatrix():Matrix3D {
		if (__worldDirty) {
			__world = parent == null ? getLocalMatrix() : Math3D.multiply(parent.getWorldMatrix(), getLocalMatrix());
			__worldDirty = false;
			worldVersion++;
		}
		return __world.clone();
	}

	/** 返回局部原点变换到世界后的新向量。 */
	public function getWorldPosition():Vector3D {
		return getWorldMatrix().transformVector(new Vector3D());
	}

	/** 检查自身和全部祖先是否可见且未销毁。 */
	public function isWorldVisible():Bool {
		return !isDisposed && visible && (parent == null || parent.isWorldVisible());
	}

	/** 幂等从父节点移除，递归销毁子树并解除所有事件监听。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		remove();
		for (child in __children.copy())
			child.dispose();
		__children = [];
		setScene(null);
		isDisposed = true;
		removeEventListeners();
	}
}
