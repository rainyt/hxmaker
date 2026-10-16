package hx.geom;

/** 射线方向使用单位向量，距离均以世界单位表达。 */
class Ray3D {
	public var origin(default, null):Vector3D;
	public var direction(default, null):Vector3D;
	public function new(origin:Vector3D, direction:Vector3D) {
		this.origin = origin.clone(); this.direction = direction.clone();
		if (this.direction.normalize() < 1e-12) throw "射线方向不能为零";
	}
	public function at(distance:Float):Vector3D {
		return new Vector3D(origin.x + direction.x * distance, origin.y + direction.y * distance, origin.z + direction.z * distance);
	}
	public function intersectsBounds(bounds:Bounds3D):Bool {
		if (bounds.isEmpty()) return false;
		var near = 0., far = Math.POSITIVE_INFINITY;
		var o = [origin.x, origin.y, origin.z], d = [direction.x, direction.y, direction.z];
		var lo = [bounds.min.x, bounds.min.y, bounds.min.z], hi = [bounds.max.x, bounds.max.y, bounds.max.z];
		for (axis in 0...3) {
			if (Math.abs(d[axis]) < 1e-12) {
				if (o[axis] < lo[axis] || o[axis] > hi[axis]) return false;
			} else {
				var a = (lo[axis] - o[axis]) / d[axis], b = (hi[axis] - o[axis]) / d[axis];
				near = Math.max(near, Math.min(a, b)); far = Math.min(far, Math.max(a, b));
				if (near > far) return false;
			}
		}
		return true;
	}
	/** 返回距离和重心坐标，不做背面剔除。 */
	public function intersectTriangle(a:Vector3D, b:Vector3D, c:Vector3D):Null<Array<Float>> {
		var edge1 = b.subtract(a), edge2 = c.subtract(a);
		var p = direction.crossProduct(edge2), det = edge1.dotProduct(p);
		if (Math.abs(det) < 1e-10) return null;
		var t = origin.subtract(a), u = t.dotProduct(p) / det;
		if (u < 0 || u > 1) return null;
		var q = t.crossProduct(edge1), v = direction.dotProduct(q) / det;
		if (v < 0 || u + v > 1) return null;
		var distance = edge2.dotProduct(q) / det;
		return distance >= 0 ? [distance, u, v] : null;
	}
}
