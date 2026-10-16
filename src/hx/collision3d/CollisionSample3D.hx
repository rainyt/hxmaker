package hx.collision3d;

import hx.geom.Vector3D;

/** 形状距离采样；normal 为分离方向，surfaceNormal 为实际表面方向。 */
typedef CollisionSample3D = {
	var separation:Float;
	var normal:Vector3D;
	var point:Vector3D;
	@:optional var surfaceNormal:Vector3D;
}
