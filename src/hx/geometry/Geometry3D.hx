package hx.geometry;

import hx.display.EventDispatcher;
import hx.events.Event;
import hx.geom.Bounds3D;
import hx.render3d.Math3D;

/** 共享 CPU 网格数据。直接修改数组后必须调用 invalidate()。 */
class Geometry3D extends EventDispatcher {
	public var positions(default, null):Array<Float>;
	public var uvs(default, null):Array<Float>;
	public var indices(default, null):Array<Int>;
	public var normals(default, null):Array<Float>;
	private var generatedNormals:Bool = false;
	public var bounds(default, null):Bounds3D;
	public var version(default, null):Int = 0;
	public var referenceCount(default, null):Int = 0;
	public var isDisposed(default, null):Bool = false;
	public function new(positions:Array<Float>, uvs:Array<Float>, indices:Array<Int>, normals:Array<Float> = null) {
		if (positions == null || uvs == null || indices == null) throw "三维几何数据不能为空";
		this.positions = positions.copy(); this.uvs = uvs.copy(); this.indices = indices.copy();
		this.normals = normals == null || normals.length == 0 ? null : normals.copy();
		invalidate();
	}
	public function invalidate():Void {
		if (isDisposed) throw "几何数据已经销毁";
		if (positions.length % 3 != 0 || uvs.length != Std.int(positions.length / 3) * 2 || indices.length % 3 != 0)
			throw "三维几何的位置、UV 或三角形索引长度无效";
		for (value in positions) if (!Math3D.finite(value)) throw "三维顶点包含无效数值";
		for (value in uvs) if (!Math3D.finite(value)) throw "三维 UV 包含无效数值";
		for (index in indices) if (index < 0 || index >= Std.int(positions.length / 3)) throw "三维索引超出顶点范围";
		if (generatedNormals) normals = null;
		if (normals != null) {
			if (normals.length != positions.length) throw "三维法线数量与位置不一致";
			for (value in normals) if (!Math3D.finite(value)) throw "三维法线包含无效数值";
		}
		bounds = new Bounds3D();
		for (i in 0...Std.int(positions.length / 3)) bounds.include(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
		version++; dispatchEvent(new Event(Event.CHANGE));
	}
	/** 缺失法线时按三角形面积累加，生成共享顶点的平滑法线。 */
	public function getNormals():Array<Float> {
		if (isDisposed) throw "几何数据已经销毁";
		if (normals != null) return normals;
		normals = [for (_ in positions) 0.]; generatedNormals = true;
		for (triangle in 0...Std.int(indices.length / 3)) {
			var a = indices[triangle*3]*3, b = indices[triangle*3+1]*3, c = indices[triangle*3+2]*3;
			var ux = positions[b]-positions[a], uy = positions[b+1]-positions[a+1], uz = positions[b+2]-positions[a+2];
			var vx = positions[c]-positions[a], vy = positions[c+1]-positions[a+1], vz = positions[c+2]-positions[a+2];
			var x = uy*vz-uz*vy, y = uz*vx-ux*vz, z = ux*vy-uy*vx;
			for (at in [a,b,c]) { normals[at] += x; normals[at+1] += y; normals[at+2] += z; }
		}
		for (vertex in 0...Std.int(normals.length / 3)) {
			var i = vertex*3, x = normals[i], y = normals[i+1], z = normals[i+2], length = Math.sqrt(x*x+y*y+z*z);
			if (length > 1e-12) { normals[i] /= length; normals[i+1] /= length; normals[i+2] /= length; }
			else { normals[i] = 0; normals[i+1] = 1; normals[i+2] = 0; }
		}
		return normals;
	}
	/** 将法线转为显式数据；之后修改位置时由调用方同步维护法线。 */
	public function setNormals(values:Array<Float>):Void {
		if (values == null || values.length != positions.length) throw "三维法线数量与位置不一致";
		for (value in values) if (!Math3D.finite(value)) throw "三维法线包含无效数值";
		normals = values.copy(); generatedNormals = false; invalidate();
	}
	public function retain():Void { if (isDisposed) throw "几何数据已经销毁"; referenceCount++; }
	public function release():Void { if (referenceCount > 0) referenceCount--; }
	public function dispose():Void {
		if (referenceCount != 0) throw "仍有模型使用此几何数据";
		if (isDisposed) return;
		isDisposed = true; positions = []; uvs = []; indices = []; normals = []; removeEventListeners();
	}
}
