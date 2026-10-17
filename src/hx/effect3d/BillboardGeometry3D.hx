package hx.effect3d;

import hx.display3d.Camera3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.geometry.Geometry3D;

/** 将世界空间广告牌写回网格局部空间，支持带旋转和非均匀缩放的父节点。 */
class BillboardGeometry3D {
	/** 返回世界空间右、上向量；锁定 Y 时保持竖直。 */
	public static function axes(camera:Camera3D, lockY:Bool = false):Array<Vector3D> {
		var m = camera.getWorldMatrix().rawData;
		var right = new Vector3D(m[0], m[1], m[2]);
		var up = new Vector3D(m[4], m[5], m[6]);
		if (lockY) { right.y = 0; up.setTo(0, 1, 0); }
		if (right.normalize() < 1e-8) right.setTo(1, 0, 0);
		// 正交化以避免相机父节点非均匀缩放造成斜切。
		var projection = up.dotProduct(right);
		up = up.subtract(new Vector3D(right.x * projection, right.y * projection, right.z * projection));
		if (up.normalize() < 1e-8) throw "相机广告牌坐标轴退化";
		return [right, up];
	}

	/** 追加一个四边形；尺寸为世界单位，旋转单位为弧度。 */
	public static function append(g:Geometry3D, inverse:Matrix3D, center:Vector3D, axes:Array<Vector3D>,
		width:Float, height:Float, rotation:Float, uv:Array<Float>, rgba:Array<Float>):Void {
		var c = Math.cos(rotation), s = Math.sin(rotation), base = Std.int(g.positions.length / 3);
		var right = axes[0], up = axes[1];
		for (i in 0...4) {
			var x = (i == 0 || i == 3 ? -0.5 : 0.5) * width;
			var y = (i < 2 ? -0.5 : 0.5) * height;
			var rx = x * c - y * s, ry = x * s + y * c;
			var p = inverse.transformVector(new Vector3D(center.x + right.x * rx + up.x * ry,
				center.y + right.y * rx + up.y * ry, center.z + right.z * rx + up.z * ry));
			g.positions.push(p.x); g.positions.push(p.y); g.positions.push(p.z);
			g.uvs.push(i == 0 || i == 3 ? uv[0] : uv[2]); g.uvs.push(i < 2 ? uv[3] : uv[1]);
			for (value in rgba) g.colors.push(value);
		}
		for (index in [0, 1, 2, 0, 2, 3]) g.indices.push(base + index);
	}

	public static function clear(g:Geometry3D):Void {
		g.positions.resize(0); g.uvs.resize(0); g.indices.resize(0); g.colors.resize(0);
	}
}
