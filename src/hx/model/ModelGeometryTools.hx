package hx.model;

/** 构建器和可修改几何共用的纯数值运算；调用前必须校验顶点及索引。 */
class ModelGeometryTools {
	/** 从 UV 导数累加切线后正交化；镜像 UV 边界应在资产中拆分顶点。 */
	public static function generateTangents(positions:Array<Float>, normals:Array<Float>, uvs:Array<Float>, indices:Array<Int>):Array<Float> {
		var t = [for (_ in positions) 0.], b = [for (_ in positions) 0.];
		for (triangle in 0...Std.int(indices.length / 3)) {
			var ia = indices[triangle * 3], ib = indices[triangle * 3 + 1], ic = indices[triangle * 3 + 2];
			var a = ia * 3, c = ic * 3, d = ib * 3;
			var du1 = uvs[ib * 2] - uvs[ia * 2], dv1 = uvs[ib * 2 + 1] - uvs[ia * 2 + 1];
			var du2 = uvs[ic * 2] - uvs[ia * 2], dv2 = uvs[ic * 2 + 1] - uvs[ia * 2 + 1];
			var determinant = du1 * dv2 - du2 * dv1;
			if (Math.abs(determinant) < 1e-12) continue;
			for (axis in 0...3) {
				var e1 = positions[d + axis] - positions[a + axis], e2 = positions[c + axis] - positions[a + axis];
				var tv = (e1 * dv2 - e2 * dv1) / determinant, bv = (e2 * du1 - e1 * du2) / determinant;
				for (offset in [a, d, c]) { t[offset + axis] += tv; b[offset + axis] += bv; }
			}
		}
		var result:Array<Float> = [];
		for (vertex in 0...Std.int(positions.length / 3)) {
			var i = vertex * 3, n = [normals[i], normals[i + 1], normals[i + 2]];
			var length = Math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
			if (!Math.isFinite(length)) throw "切线法线超出可计算数值范围";
			if (length < 1e-12) n = [0., 1., 0.]; else for (axis in 0...3) n[axis] /= length;
			var projection = n[0] * t[i] + n[1] * t[i + 1] + n[2] * t[i + 2];
			var x = t[i] - n[0] * projection, y = t[i + 1] - n[1] * projection, z = t[i + 2] - n[2] * projection;
			length = Math.sqrt(x * x + y * y + z * z);
			if (!Math.isFinite(length)) throw "切线生成超出可计算数值范围";
			if (length < 1e-12) {
				// UV 退化时使用确定的垂直方向，避免法线贴图产生 NaN。
				if (Math.abs(n[1]) < 0.9) { x = n[2]; y = 0; z = -n[0]; }
				else { x = 0; y = -n[2]; z = n[1]; }
				length = Math.sqrt(x * x + y * y + z * z);
			}
			x /= length; y /= length; z /= length;
			var handedness = (n[1] * z - n[2] * y) * b[i] + (n[2] * x - n[0] * z) * b[i + 1]
				+ (n[0] * y - n[1] * x) * b[i + 2] < 0 ? -1. : 1.;
			for (value in [x, y, z, handedness]) result.push(value);
		}
		return result;
	}

	/** 按三角形面积累加共享顶点法线；退化面沿用几何类的向上法线回退。 */
	public static function generateNormals(positions:Array<Float>, indices:Array<Int>):Array<Float> {
		var result = [for (_ in positions) 0.];
		for (triangle in 0...Std.int(indices.length / 3)) {
			var a = indices[triangle * 3] * 3, b = indices[triangle * 3 + 1] * 3, c = indices[triangle * 3 + 2] * 3;
			var ux = positions[b] - positions[a], uy = positions[b + 1] - positions[a + 1], uz = positions[b + 2] - positions[a + 2];
			var vx = positions[c] - positions[a], vy = positions[c + 1] - positions[a + 1], vz = positions[c + 2] - positions[a + 2];
			var x = uy * vz - uz * vy, y = uz * vx - ux * vz, z = ux * vy - uy * vx;
			for (offset in [a, b, c]) {
				result[offset] += x;
				result[offset + 1] += y;
				result[offset + 2] += z;
			}
		}
		for (vertex in 0...Std.int(positions.length / 3)) {
			var i = vertex * 3, x = result[i], y = result[i + 1], z = result[i + 2];
			var length = Math.sqrt(x * x + y * y + z * z);
			if (!Math.isFinite(length)) throw "法线生成超出可计算数值范围";
			if (length > 1e-12) {
				result[i] /= length;
				result[i + 1] /= length;
				result[i + 2] /= length;
			} else {
				result[i] = 0;
				result[i + 1] = 1;
				result[i + 2] = 0;
			}
		}
		return result;
	}
}
