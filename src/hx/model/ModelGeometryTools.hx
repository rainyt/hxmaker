package hx.model;

/** 构建器和可修改几何共用的纯数值运算；调用前必须校验顶点及索引。 */
class ModelGeometryTools {
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
