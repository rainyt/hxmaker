package hx.collision3d;

import hx.geom.Vector3D;

/** 形状距离采样；normal 为分离方向，surfaceNormal 为实际表面方向。 */
typedef CollisionSample3D = {
	/** 有符号表面分离量，正值为间隔，零为接触，负值为重叠。 */
	var separation:Float;

	/** 世界单位分离法线，由表面朝向查询形状。 */
	var normal:Vector3D;

	/** 代理表面的世界最近点。 */
	var point:Vector3D;

	/** 可选真实表面法线；未提供时由查询结果采用分离法线。 */
	@:optional var surfaceNormal:Vector3D;
}
