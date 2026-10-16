package hx.display;

import hx.events.Event;
import hx.geom.Bounds3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;

/** 三维网格节点；几何和材质可共享，销毁节点仅释放引用。 */
class MeshObject extends Node3D {
	public var geometry(get, set):Geometry3D;
	public var material(get, set):Material3D;
	public var pickable:Bool = true;
	public var frustumCulling:Bool = true;
	private var __geometry:Geometry3D;
	private var __material:Material3D;
	private var __vertices:Array<Float> = [];
	private var __geometryVersion:Int = -1;
	private var __worldVersion:Int = -1;
	public function new(geometry:Geometry3D, material:Material3D) {
		super(); this.geometry = geometry; this.material = material;
	}
	private function get_geometry():Geometry3D { return __geometry; }
	private function set_geometry(value:Geometry3D):Geometry3D {
		if (isDisposed) throw "模型已经销毁";
		if (value == __geometry) return value;
		if (value != null) value.retain();
		if (__geometry != null) { __geometry.removeEventListener(Event.CHANGE, onResourceChange); __geometry.release(); }
		__geometry = value; __geometryVersion = -1;
		if (value != null) value.addEventListener(Event.CHANGE, onResourceChange);
		invalidate(); return value;
	}
	private function get_material():Material3D { return __material; }
	private function set_material(value:Material3D):Material3D {
		if (isDisposed) throw "模型已经销毁";
		if (value == __material) return value;
		if (value != null) value.retain();
		if (__material != null) { __material.removeEventListener(Event.CHANGE, onResourceChange); __material.release(); }
		__material = value;
		if (value != null) value.addEventListener(Event.CHANGE, onResourceChange);
		invalidate(); return value;
	}
	private function onResourceChange(event:Event):Void { invalidate(); }
	/** 返回只供渲染器读取的缓存；调用方不得修改。 */
	public function getWorldVertices():Array<Float> {
		if (__geometry == null) return [];
		var matrix = getWorldMatrix();
		if (__geometryVersion != __geometry.version || __worldVersion != worldVersion) {
			__vertices = []; matrix.transformVectors(__geometry.positions, __vertices);
			__geometryVersion = __geometry.version; __worldVersion = worldVersion;
		}
		return __vertices;
	}
	public function getWorldBounds():Bounds3D {
		return __geometry == null ? new Bounds3D() : __geometry.bounds.transformed(getWorldMatrix());
	}
	override public function dispose():Void {
		if (isDisposed) return;
		geometry = null; material = null; __vertices = []; super.dispose();
	}
}
