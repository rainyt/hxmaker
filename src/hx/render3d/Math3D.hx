package hx.render3d;

import hx.geom.Matrix3D;
import hx.geom.Vector3D;

/** 三维子系统统一使用列向量和列主序矩阵，避免依赖 append 的命名语义。 */
class Math3D {
	/** glTF 四元数使用 x、y、z、w 顺序，直接生成 T×R×S，避免欧拉角往返。 */
	public static function fromTRS(t:Array<Float>, q:Array<Float>, s:Array<Float>):Matrix3D {
		var x = q[0], y = q[1], z = q[2], w = q[3];
		return new Matrix3D([
			(1 - 2 * (y*y + z*z))*s[0], 2*(x*y + z*w)*s[0], 2*(x*z - y*w)*s[0], 0,
			2*(x*y - z*w)*s[1], (1 - 2 * (x*x + z*z))*s[1], 2*(y*z + x*w)*s[1], 0,
			2*(x*z + y*w)*s[2], 2*(y*z - x*w)*s[2], (1 - 2 * (x*x + y*y))*s[2], 0,
			t[0], t[1], t[2], 1
		]);
	}

	public static function multiply(a:Matrix3D, b:Matrix3D):Matrix3D {
		var out = new Matrix3D();
		for (column in 0...4) {
			for (row in 0...4) {
				var value = 0.;
				for (k in 0...4) value += a.rawData[k * 4 + row] * b.rawData[column * 4 + k];
				out.rawData[column * 4 + row] = value;
			}
		}
		return out;
	}

	public static function compose(x:Float, y:Float, z:Float, rx:Float, ry:Float, rz:Float, sx:Float, sy:Float, sz:Float):Matrix3D {
		var factor = Math.PI / 180;
		var cx = Math.cos(rx * factor), ax = Math.sin(rx * factor);
		var cy = Math.cos(ry * factor), ay = Math.sin(ry * factor);
		var cz = Math.cos(rz * factor), az = Math.sin(rz * factor);
		return new Matrix3D([
			cz * cy * sx, az * cy * sx, -ay * sx, 0,
			(cz * ay * ax - az * cx) * sy, (az * ay * ax + cz * cx) * sy, cy * ax * sy, 0,
			(cz * ay * cx + az * ax) * sz, (az * ay * cx - cz * ax) * sz, cy * cx * sz, 0,
			x, y, z, 1
		]);
	}

	public static function project(matrix:Matrix3D, x:Float, y:Float, z:Float):Vector3D {
		var p = matrix.transformVector(new Vector3D(x, y, z));
		if (Math.abs(p.w) < 1e-12) throw "三维坐标无法完成齐次除法";
		return new Vector3D(p.x / p.w, p.y / p.w, p.z / p.w);
	}

	public static function finite(value:Float):Bool {
		return !Math.isNaN(value) && Math.isFinite(value);
	}
}
