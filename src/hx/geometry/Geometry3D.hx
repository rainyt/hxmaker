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
	public var bounds(default, null):Bounds3D;
	public var version(default, null):Int = 0;
	public var referenceCount(default, null):Int = 0;
	public var isDisposed(default, null):Bool = false;
	public function new(positions:Array<Float>, uvs:Array<Float>, indices:Array<Int>) {
		if (positions == null || uvs == null || indices == null) throw "三维几何数据不能为空";
		this.positions = positions.copy(); this.uvs = uvs.copy(); this.indices = indices.copy();
		invalidate();
	}
	public function invalidate():Void {
		if (isDisposed) throw "几何数据已经销毁";
		if (positions.length % 3 != 0 || uvs.length != Std.int(positions.length / 3) * 2 || indices.length % 3 != 0)
			throw "三维几何的位置、UV 或三角形索引长度无效";
		for (value in positions) if (!Math3D.finite(value)) throw "三维顶点包含无效数值";
		for (value in uvs) if (!Math3D.finite(value)) throw "三维 UV 包含无效数值";
		for (index in indices) if (index < 0 || index >= Std.int(positions.length / 3)) throw "三维索引超出顶点范围";
		bounds = new Bounds3D();
		for (i in 0...Std.int(positions.length / 3)) bounds.include(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
		version++; dispatchEvent(new Event(Event.CHANGE));
	}
	public function retain():Void { if (isDisposed) throw "几何数据已经销毁"; referenceCount++; }
	public function release():Void { if (referenceCount > 0) referenceCount--; }
	public function dispose():Void {
		if (referenceCount != 0) throw "仍有模型使用此几何数据";
		if (isDisposed) return;
		isDisposed = true; positions = []; uvs = []; indices = []; removeEventListeners();
	}
}
