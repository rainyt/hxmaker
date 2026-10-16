package hx.display;

import hx.geom.Matrix3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 右手透视相机，默认朝向局部 -Z；相机参数直接修改后由场景更新检查。 */
class Camera3D extends Node3D {
	public var fieldOfView:Float = 60;
	public var near:Float = 0.1;
	public var far:Float = 1000;
	public function new() { super(); }
	public function getViewMatrix():Matrix3D {
		var result = getWorldMatrix();
		if (!result.invert()) throw "相机世界矩阵不可逆";
		return result;
	}
	public function getProjectionMatrix(aspect:Float):Matrix3D {
		if (!Math3D.finite(aspect) || aspect <= 0 || !Math3D.finite(fieldOfView) || fieldOfView <= 0 || fieldOfView >= 180
			|| !Math3D.finite(near) || !Math3D.finite(far) || near <= 0 || far <= near) throw "透视相机参数无效";
		var f = 1 / Math.tan(fieldOfView * Math.PI / 360), range = 1 / (near - far);
		return new Matrix3D([f/aspect,0.,0.,0., 0.,f,0.,0., 0.,0.,(far+near)*range,-1., 0.,0.,2*far*near*range,0.]);
	}
	public function getViewProjection(aspect:Float):Matrix3D {
		return Math3D.multiply(getProjectionMatrix(aspect), getViewMatrix());
	}
	/** 目标和上方向使用世界坐标，精确矩阵会抵消父节点变换。 */
	public function lookAt(target:Vector3D, up:Vector3D = null):Void {
		lookFrom(getWorldPosition(), target, up);
	}
	/** 同时设置世界位置与观察目标，不把世界位置误作父节点局部坐标。 */
	public function lookFrom(position:Vector3D, target:Vector3D, up:Vector3D = null):Void {
		if (isDisposed) throw "相机已经销毁";
		if (position == null || target == null) throw "相机位置与观察目标不能为空";
		if (up == null) up = new Vector3D(0, 1, 0);
		for (value in [position.x, position.y, position.z, target.x, target.y, target.z, up.x, up.y, up.z])
			if (!Math3D.finite(value)) throw "相机观察参数必须是有限数值";
		var z = position.subtract(target);
		if (z.normalize() < 1e-10) throw "相机与观察目标不能重合";
		var x = up.crossProduct(z);
		if (x.normalize() < 1e-10) throw "相机上方向与观察方向不能平行";
		var y = z.crossProduct(x);
		var world = new Matrix3D([x.x,x.y,x.z,0., y.x,y.y,y.z,0., z.x,z.y,z.z,0., position.x,position.y,position.z,1.]);
		if (parent != null) {
			var inverse = parent.getWorldMatrix();
			if (!inverse.invert()) throw "相机父节点矩阵不可逆";
			world = Math3D.multiply(inverse, world);
		}
		var previous = getLocalMatrix(), changed = false;
		for (i in 0...16) if (previous.rawData[i] != world.rawData[i]) { changed = true; break; }
		if (changed) setLocalMatrix(world);
	}
	public function screenRay(localX:Float, localY:Float, width:Float, height:Float):Ray3D {
		for (value in [localX, localY, width, height]) if (!Math3D.finite(value)) throw "视口射线坐标必须是有限数值";
		if (width <= 0 || height <= 0 || isDisposed) throw "相机或视口尺寸无效";
		var inverse = getViewProjection(width / height);
		if (!inverse.invert()) throw "相机视图投影矩阵不可逆";
		var x = localX / width * 2 - 1, y = 1 - localY / height * 2;
		var start = Math3D.project(inverse, x, y, -1), end = Math3D.project(inverse, x, y, 1);
		return new Ray3D(start, end.subtract(start));
	}
}
