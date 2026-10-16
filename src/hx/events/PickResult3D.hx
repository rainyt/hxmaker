package hx.events;

import hx.display.MeshObject;
import hx.geom.Vector3D;
import hx.geom.Point;

/** 几何拾取结果，不包含纹理 Alpha 像素检测。 */
class PickResult3D {
	public var object:MeshObject;
	public var position:Vector3D;
	public var distance:Float;
	public var triangleIndex:Int;
	public var uv:Point;
	public function new(object:MeshObject, position:Vector3D, distance:Float, triangleIndex:Int, uv:Point) {
		this.object = object; this.position = position; this.distance = distance;
		this.triangleIndex = triangleIndex; this.uv = uv;
	}
}
