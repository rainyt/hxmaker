package hx.geom;

/** 轴对齐包围盒；通过八个角变换生成保守世界包围盒。 */
class Bounds3D {
	/** 轴对齐包围盒的最小角；空盒初始为正无穷。 */
	public var min:Vector3D;

	/** 轴对齐包围盒的最大角；空盒初始为负无穷。 */
	public var max:Vector3D;

	/** 创建空轴对齐包围盒。 */
	public function new() {
		reset();
	}

	/** 清空边界，后续可通过 include 重新累加。 */
	public function reset():Void {
		min = new Vector3D(Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY, Math.POSITIVE_INFINITY);
		max = new Vector3D(Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY, Math.NEGATIVE_INFINITY);
	}

	/** 将给定坐标纳入包围盒。 */
	public function include(x:Float, y:Float, z:Float):Void {
		min.x = Math.min(min.x, x);
		min.y = Math.min(min.y, y);
		min.z = Math.min(min.z, z);
		max.x = Math.max(max.x, x);
		max.y = Math.max(max.y, y);
		max.z = Math.max(max.z, z);
	}

	/** 任一轴最小值大于最大值时返回 true。 */
	public function isEmpty():Bool {
		return min.x > max.x || min.y > max.y || min.z > max.z;
	}

	/** 返回最小角和最大角的中点，调用前应确认非空。 */
	public function center():Vector3D {
		return new Vector3D((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2);
	}

	/** 变换八个角并返回包围它们的新 AABB，不修改原包围盒。 */
	public function transformed(matrix:Matrix3D):Bounds3D {
		var result = new Bounds3D();
		if (!isEmpty())
			for (i in 0...8) {
				var p = matrix.transformVector(new Vector3D((i & 1) == 0 ? min.x : max.x, (i & 2) == 0 ? min.y : max.y, (i & 4) == 0 ? min.z : max.z));
				result.include(p.x, p.y, p.z);
			}
		return result;
	}

	/** 所有角都在同一裁剪面之外时才剔除。 */
	public function inFrustum(viewProjection:Matrix3D):Bool {
		if (isEmpty())
			return true;
		var outside = [0, 0, 0, 0, 0, 0];
		for (i in 0...8) {
			var p = viewProjection.transformVector(new Vector3D((i & 1) == 0 ? min.x : max.x, (i & 2) == 0 ? min.y : max.y, (i & 4) == 0 ? min.z : max.z));
			if (p.x < -p.w)
				outside[0]++;
			if (p.x > p.w)
				outside[1]++;
			if (p.y < -p.w)
				outside[2]++;
			if (p.y > p.w)
				outside[3]++;
			if (p.z < -p.w)
				outside[4]++;
			if (p.z > p.w)
				outside[5]++;
		}
		for (count in outside)
			if (count == 8)
				return false;
		return true;
	}
}
