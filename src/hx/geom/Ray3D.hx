package hx.geom;

import hx.render3d.Math3D;

/** 射线方向使用单位向量，距离均以世界单位表达。 */
class Ray3D {
	/** 构造时复制的世界起点；后续查询会重新校验公开向量。 */
	public var origin(default, null):Vector3D;

	/** 构造时复制并归一化的世界方向。 */
	public var direction(default, null):Vector3D;

	/** 复制有限起点与非零方向，归一化方向以保持距离为世界单位。 */
	public function new(origin:Vector3D, direction:Vector3D) {
		if (origin == null || direction == null)
			throw "射线起点与方向不能为空";
		for (value in [origin.x, origin.y, origin.z, direction.x, direction.y, direction.z])
			if (!Math3D.finite(value))
				throw "射线必须包含有限坐标";
		this.origin = origin.clone();
		this.direction = direction.clone();
		var magnitude = Math.max(Math.abs(direction.x), Math.max(Math.abs(direction.y), Math.abs(direction.z)));
		if (magnitude == 0)
			throw "射线方向不能为零";
		this.direction.x /= magnitude;
		this.direction.y /= magnitude;
		this.direction.z /= magnitude;
		this.direction.normalize();
	}

	/** 返回沿射线前进给定世界距离后的新位置。 */
	public function at(distance:Float):Vector3D {
		return new Vector3D(origin.x + direction.x * distance, origin.y + direction.y * distance, origin.z + direction.z * distance);
	}

	/** 平面方程 normal·position + constant = 0；平行或共面时返回 null。 */
	public function intersectPlane(normal:Vector3D, constant:Float, maxDistance:Null<Float> = null):Null<Float> {
		var limit:Float = maxDistance == null ? Math.POSITIVE_INFINITY : maxDistance;
		if (normal == null || !Math3D.finite(constant) || Math.isNaN(limit) || limit < 0)
			throw "平面求交参数无效";
		for (value in [normal.x, normal.y, normal.z])
			if (!Math3D.finite(value))
				throw "平面法线必须是有限数值";
		var magnitude = Math.max(Math.abs(normal.x), Math.max(Math.abs(normal.y), Math.abs(normal.z)));
		if (magnitude == 0)
			throw "平面法线不能为零";
		var nx = normal.x / magnitude,
			ny = normal.y / magnitude,
			nz = normal.z / magnitude;
		var length = Math.sqrt(nx * nx + ny * ny + nz * nz),
			denominator = nx * direction.x + ny * direction.y + nz * direction.z;
		if (Math.abs(denominator) < 1e-10 * length)
			return null;
		var distance = -(nx * origin.x + ny * origin.y + nz * origin.z + constant / magnitude) / denominator;
		return Math3D.finite(distance) && distance >= 0 && distance <= limit ? distance : null;
	}

	/** 用分离轴区间检查前向射线是否经过轴对齐包围盒。 */
	public function intersectsBounds(bounds:Bounds3D):Bool {
		if (bounds.isEmpty())
			return false;
		var near = 0., far = Math.POSITIVE_INFINITY;
		var o = [origin.x, origin.y, origin.z],
			d = [direction.x, direction.y, direction.z];
		var lo = [bounds.min.x, bounds.min.y, bounds.min.z],
			hi = [bounds.max.x, bounds.max.y, bounds.max.z];
		for (axis in 0...3) {
			if (Math.abs(d[axis]) < 1e-12) {
				if (o[axis] < lo[axis] || o[axis] > hi[axis])
					return false;
			} else {
				var a = (lo[axis] - o[axis]) / d[axis],
					b = (hi[axis] - o[axis]) / d[axis];
				near = Math.max(near, Math.min(a, b));
				far = Math.min(far, Math.max(a, b));
				if (near > far)
					return false;
			}
		}
		return true;
	}

	/** 返回距离和重心坐标，不做背面剔除。 */
	public function intersectTriangle(a:Vector3D, b:Vector3D, c:Vector3D):Null<Array<Float>> {
		var edge1 = b.subtract(a), edge2 = c.subtract(a);
		var p = direction.crossProduct(edge2), det = edge1.dotProduct(p);
		if (Math.abs(det) < 1e-10)
			return null;
		var t = origin.subtract(a), u = t.dotProduct(p) / det;
		if (u < 0 || u > 1)
			return null;
		var q = t.crossProduct(edge1), v = direction.dotProduct(q) / det;
		if (v < 0 || u + v > 1)
			return null;
		var distance = edge2.dotProduct(q) / det;
		return distance >= 0 ? [distance, u, v] : null;
	}
}
