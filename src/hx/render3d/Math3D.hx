package hx.render3d;

import hx.geom.Matrix3D;
import hx.geom.Vector3D;

/** 三维子系统统一使用列向量和列主序矩阵，避免依赖 append 的命名语义。 */
class Math3D {
	/** 切线用线性矩阵变换，再相对已变换法线正交化；负行列式同步翻转手性。 */
	public static function transformTangent(m:Array<Float>, x:Float, y:Float, z:Float, handedness:Float,
		nx:Float, ny:Float, nz:Float, out:Array<Float>, offset:Int):Void {
		var tx = m[0] * x + m[4] * y + m[8] * z;
		var ty = m[1] * x + m[5] * y + m[9] * z;
		var tz = m[2] * x + m[6] * y + m[10] * z;
		var projection = (tx * nx + ty * ny + tz * nz) / Math.max(nx * nx + ny * ny + nz * nz, 1e-12);
		tx -= nx * projection; ty -= ny * projection; tz -= nz * projection;
		var length = Math.sqrt(tx * tx + ty * ty + tz * tz);
		if (length < 1e-12) {
			if (Math.abs(ny) < 0.9) { tx = nz; ty = 0; tz = -nx; }
			else { tx = 0; ty = -nz; tz = ny; }
			length = Math.sqrt(tx * tx + ty * ty + tz * tz);
			if (length < 1e-12) { tx = 1; ty = tz = 0; length = 1; }
		}
		if (!Math.isFinite(length)) throw "切线变换超出可计算数值范围";
		var determinant = m[0] * (m[5] * m[10] - m[9] * m[6]) - m[4] * (m[1] * m[10] - m[9] * m[2])
			+ m[8] * (m[1] * m[6] - m[5] * m[2]);
		out[offset] = tx / length; out[offset + 1] = ty / length; out[offset + 2] = tz / length;
		out[offset + 3] = handedness * (determinant < 0 ? -1 : 1);
	}

	/** 逆转置法线变换；复用输出数组，归一化时保留负行列式的方向。 */
	public static function transformNormal(m:Array<Float>, x:Float, y:Float, z:Float, out:Array<Float>, offset:Int):Void {
		var c00 = m[5] * m[10] - m[9] * m[6],
			c01 = m[9] * m[2] - m[1] * m[10],
			c02 = m[1] * m[6] - m[5] * m[2];
		var c10 = m[8] * m[6] - m[4] * m[10],
			c11 = m[0] * m[10] - m[8] * m[2],
			c12 = m[4] * m[2] - m[0] * m[6];
		var c20 = m[4] * m[9] - m[8] * m[5],
			c21 = m[8] * m[1] - m[0] * m[9],
			c22 = m[0] * m[5] - m[4] * m[1];
		var sign = m[0] * c00 + m[4] * c01 + m[8] * c02 < 0 ? -1. : 1.;
		var nx = (c00 * x + c01 * y + c02 * z) * sign,
			ny = (c10 * x + c11 * y + c12 * z) * sign,
			nz = (c20 * x + c21 * y + c22 * z) * sign;
		var length = Math.sqrt(nx * nx + ny * ny + nz * nz);
		if (length > 1e-12) {
			nx /= length;
			ny /= length;
			nz /= length;
		} else {
			nx = 0;
			ny = 1;
			nz = 0;
		}
		out[offset] = nx;
		out[offset + 1] = ny;
		out[offset + 2] = nz;
	}

	/** 正交投影，near / far 为沿相机 -Z 方向的有符号距离。 */
	public static function orthographic(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float):Matrix3D {
		for (value in [left, right, bottom, top, near, far, right - left, top - bottom, far - near])
			if (!finite(value))
				throw "正交投影范围必须是有限值";
		if (right <= left || top <= bottom || far <= near)
			throw "正交投影范围无效";
		return new Matrix3D([
			2 / (right - left),
			0.,
			0.,
			0.,
			0.,
			2 / (top - bottom),
			0.,
			0.,
			0.,
			0.,
			-2 / (far - near),
			0.,
			-(right + left) / (right - left),
			-(top + bottom) / (top - bottom),
			-(far + near) / (far - near),
			1.
		]);
	}

	/** glTF 四元数使用 x、y、z、w 顺序，直接生成 T×R×S，避免欧拉角往返。 */
	public static function fromTRS(t:Array<Float>, q:Array<Float>, s:Array<Float>):Matrix3D {
		var x = q[0], y = q[1], z = q[2], w = q[3];
		return new Matrix3D([
			(1 - 2 * (y * y + z * z)) * s[0],       2 * (x * y + z * w) * s[0],       2 * (x * z - y * w) * s[0], 0,
			      2 * (x * y - z * w) * s[1], (1 - 2 * (x * x + z * z)) * s[1],       2 * (y * z + x * w) * s[1], 0,
			      2 * (x * z + y * w) * s[2],       2 * (y * z - x * w) * s[2], (1 - 2 * (x * x + y * y)) * s[2], 0,
			                            t[0],                             t[1],                             t[2], 1
		]);
	}

	/** 返回 a*b 的四阶矩阵乘积，遵循三维列向量约定。 */
	public static function multiply(a:Matrix3D, b:Matrix3D):Matrix3D {
		var out = new Matrix3D();
		for (column in 0...4) {
			for (row in 0...4) {
				var value = 0.;
				for (k in 0...4)
					value += a.rawData[k * 4 + row] * b.rawData[column * 4 + k];
				out.rawData[column * 4 + row] = value;
			}
		}
		return out;
	}

	/** 用平移、欧拉角度和缩放合成局部四阶矩阵。 */
	public static function compose(x:Float, y:Float, z:Float, rx:Float, ry:Float, rz:Float, sx:Float, sy:Float, sz:Float):Matrix3D {
		var factor = Math.PI / 180;
		var cx = Math.cos(rx * factor), ax = Math.sin(rx * factor);
		var cy = Math.cos(ry * factor), ay = Math.sin(ry * factor);
		var cz = Math.cos(rz * factor), az = Math.sin(rz * factor);
		return new Matrix3D([
			                 cz * cy * sx,                  az * cy * sx,     -ay * sx, 0,
			(cz * ay * ax - az * cx) * sy, (az * ay * ax + cz * cx) * sy, cy * ax * sy, 0,
			(cz * ay * cx + az * ax) * sz, (az * ay * cx - cz * ax) * sz, cy * cx * sz, 0,
			                            x,                             y,            z, 1
		]);
	}

	/** 将给定坐标乘矩阵并除以齐次 W，返回投影后的新三维坐标。 */
	public static function project(matrix:Matrix3D, x:Float, y:Float, z:Float):Vector3D {
		var p = matrix.transformVector(new Vector3D(x, y, z));
		if (Math.abs(p.w) < 1e-12)
			throw "三维坐标无法完成齐次除法";
		return new Vector3D(p.x / p.w, p.y / p.w, p.z / p.w);
	}

	/** 判断浮点数是否有限，排除 NaN 与正负无穷。 */
	public static function finite(value:Float):Bool {
		return !Math.isNaN(value) && Math.isFinite(value);
	}
}
