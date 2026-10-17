package hx.formats.fbx;

/** 平面简单多边形的耳切三角化；返回面内角点索引，保留逐角点 UV 和法线。 */
class FbxTriangulator {
	public static function triangulate(vertices:Array<Float>, polygon:Array<Int>):Array<Int> {
		if (polygon.length < 3 || polygon.length > 256) throw "FBX 多边形需要 3 至 256 个角点";
		var nx = 0., ny = 0., nz = 0.;
		for (i in 0...polygon.length) {
			var a = polygon[i] * 3, b = polygon[(i + 1) % polygon.length] * 3;
			nx += (vertices[a + 1] - vertices[b + 1]) * (vertices[a + 2] + vertices[b + 2]);
			ny += (vertices[a + 2] - vertices[b + 2]) * (vertices[a] + vertices[b]);
			nz += (vertices[a] - vertices[b]) * (vertices[a + 1] + vertices[b + 1]);
		}
		var length = Math.sqrt(nx * nx + ny * ny + nz * nz);
		if (!Math.isFinite(length) || length < 1e-12) throw "FBX 多边形退化或无法确定平面";
		var drop = Math.abs(nx) >= Math.abs(ny) && Math.abs(nx) >= Math.abs(nz) ? 0 : Math.abs(ny) >= Math.abs(nz) ? 1 : 2;
		var x:Array<Float> = [], y:Array<Float> = [], extent = 0.;
		var origin = polygon[0] * 3;
		for (index in polygon) {
			var at = index * 3;
			x.push(vertices[at + (drop == 0 ? 1 : 0)] - vertices[origin + (drop == 0 ? 1 : 0)]);
			y.push(vertices[at + (drop == 2 ? 1 : 2)] - vertices[origin + (drop == 2 ? 1 : 2)]);
			for (axis in 0...3) extent = Math.max(extent, Math.abs(vertices[at + axis] - vertices[origin + axis]));
		}
		for (index in polygon) {
			var at = index * 3;
			var distance = ((vertices[at] - vertices[origin]) * nx + (vertices[at + 1] - vertices[origin + 1]) * ny
				+ (vertices[at + 2] - vertices[origin + 2]) * nz) / length;
			if (Math.abs(distance) > extent * 1e-5 + 1e-8) throw "FBX 非平面多边形请先在建模工具中三角化";
		}
		var area = 0., epsilon = Math.max(1e-14, extent * extent * 1e-12);
		for (a in 0...polygon.length) {
			var b = (a + 1) % polygon.length;
			if (Math.abs(x[a] - x[b]) + Math.abs(y[a] - y[b]) <= Math.sqrt(epsilon)) throw "FBX 多边形包含重复相邻角点";
			for (c in (a + 1)...polygon.length) {
				var d = (c + 1) % polygon.length;
				if (c == b || d == a) continue;
				if (intersects(x, y, a, b, c, d, epsilon)) throw "FBX 多边形存在相交边，请先在建模工具中修复";
			}
		}
		for (i in 0...polygon.length) area += x[i] * y[(i + 1) % polygon.length] - x[(i + 1) % polygon.length] * y[i];
		if (Math.abs(area) <= epsilon) throw "FBX 多边形面积为零";
		var sign = area > 0 ? 1. : -1., remaining = [for (i in 0...polygon.length) i], output:Array<Int> = [];
		while (remaining.length > 3) {
			var found = false;
			for (i in 0...remaining.length) {
				var a = remaining[(i + remaining.length - 1) % remaining.length], b = remaining[i], c = remaining[(i + 1) % remaining.length];
				if (cross(x, y, a, b, c) * sign <= epsilon) continue;
				var contains = false;
				for (p in remaining)
					if (p != a && p != b && p != c && cross(x, y, a, b, p) * sign >= -epsilon
						&& cross(x, y, b, c, p) * sign >= -epsilon && cross(x, y, c, a, p) * sign >= -epsilon) {
						contains = true; break;
					}
				if (contains) continue;
				output.push(a); output.push(b); output.push(c);
				remaining.splice(i, 1); found = true; break;
			}
			if (!found) throw "FBX 多边形可能自交、重复角点或存在无法处理的退化边，请先三角化";
		}
		if (cross(x, y, remaining[0], remaining[1], remaining[2]) * sign <= epsilon) throw "FBX 最后一个三角形退化";
		for (index in remaining) output.push(index);
		return output;
	}

	private static function cross(x:Array<Float>, y:Array<Float>, a:Int, b:Int, c:Int):Float {
		return (x[b] - x[a]) * (y[c] - y[a]) - (y[b] - y[a]) * (x[c] - x[a]);
	}

	private static function intersects(x:Array<Float>, y:Array<Float>, a:Int, b:Int, c:Int, d:Int, epsilon:Float):Bool {
		var abC = cross(x,y,a,b,c), abD = cross(x,y,a,b,d), cdA = cross(x,y,c,d,a), cdB = cross(x,y,c,d,b);
		if (((abC > epsilon && abD < -epsilon) || (abC < -epsilon && abD > epsilon))
			&& ((cdA > epsilon && cdB < -epsilon) || (cdA < -epsilon && cdB > epsilon))) return true;
		var tolerance = Math.sqrt(epsilon);
		return (Math.abs(abC) <= epsilon && between(x,y,a,b,c,tolerance)) || (Math.abs(abD) <= epsilon && between(x,y,a,b,d,tolerance))
			|| (Math.abs(cdA) <= epsilon && between(x,y,c,d,a,tolerance)) || (Math.abs(cdB) <= epsilon && between(x,y,c,d,b,tolerance));
	}

	private static function between(x:Array<Float>, y:Array<Float>, a:Int, b:Int, p:Int, tolerance:Float):Bool {
		return x[p] >= Math.min(x[a],x[b]) - tolerance && x[p] <= Math.max(x[a],x[b]) + tolerance
			&& y[p] >= Math.min(y[a],y[b]) - tolerance && y[p] <= Math.max(y[a],y[b]) + tolerance;
	}
}
