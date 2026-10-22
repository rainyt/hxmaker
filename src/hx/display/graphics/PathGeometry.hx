package hx.display.graphics;

import hx.display.graphics.GraphicsPath.PathContour;
import hx.geom.Point;

/** 将路径轮廓转换为现有渲染后端可直接消费的三角形网格。 */
@:noCompletion
class PathGeometry {
	private static inline var EPS:Float = 1e-12;

	/** 通过弦高误差确定圆弧细分数，并限制单段跨度和总点数。 */
	public static function arcSteps(radius:Float, sweep:Float, tolerance:Float):Int {
		if (radius <= 0 || sweep == 0) return 0;
		// 使用 asin 形式，避免半径较大时 1 - tolerance / radius 的消减误差。
		var step = Math.min(Math.PI / 2, 4 * Math.asin(Math.sqrt(Math.min(1, tolerance / radius * 0.5))));
		var requested = sweep / step;
		if (!Math.isFinite(requested) || requested > 16384)
			throw "圆弧细分超过了 16384 段，请增大误差或拆分路径";
		return Std.int(Math.max(1, Math.ceil(requested)));
	}

	/** 填充简单凹多边形。多个轮廓必须互不相交、接触或嵌套。 */
	public static function fill(contours:Array<PathContour>):GraphicsMesh {
		var mesh = new GraphicsMesh();
		var rings:Array<FillRing> = [];
		var count = 0;
		for (contour in contours) {
			count += contour.points.length;
			if (count > 2048) throw "单次路径填充最多支持 2048 个细分点，请拆分路径或增大误差";
			if (contour.points.length < 3) continue;
			var minX = Math.POSITIVE_INFINITY, minY = Math.POSITIVE_INFINITY;
			var maxX = Math.NEGATIVE_INFINITY, maxY = Math.NEGATIVE_INFINITY;
			for (p in contour.points) {
				minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
				maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y);
			}
			var scale = Math.max(maxX - minX, maxY - minY);
			if (!Math.isFinite(scale)) throw "填充路径坐标范围过大";
			if (scale == 0) continue;
			// 各轮廓分别归一化，避免远处的大轮廓使小轮廓被全局容差吞掉。
			var points = [for (p in contour.points) new Point((p.x - minX) / scale, (p.y - minY) / scale)];
			points = cleanRing(points);
			if (points.length >= 3) rings.push({points: points, x: minX, y: minY, maxX: maxX, maxY: maxY, scale: scale});
		}
		for (r in 0...rings.length) {
			var entry = rings[r], ring = entry.points, n = ring.length;
			for (i in 0...n) for (j in (i + 1)...n) {
				if (j == i + 1 || (i == 0 && j == n - 1)) continue;
				if (intersects(ring[i], ring[(i + 1) % n], ring[j], ring[(j + 1) % n]))
					throw "填充路径包含自交或重叠边，请拆分为简单轮廓";
			}
			for (other in (r + 1)...rings.length) {
				var second = rings[other];
				if (entry.maxX < second.x || second.maxX < entry.x || entry.maxY < second.y || second.maxY < entry.y) continue;
				// 只有包围盒重叠的轮廓才需要在同一坐标空间做相交与包含判断。
				var scale = Math.max(entry.scale, second.scale);
				var a = [for (p in ring) new Point(p.x * (entry.scale / scale), p.y * (entry.scale / scale))];
				var b = [for (p in second.points) new Point((second.x - entry.x) / scale + p.x * (second.scale / scale),
					(second.y - entry.y) / scale + p.y * (second.scale / scale))];
				for (i in 0...n) for (j in 0...b.length)
					if (intersects(a[i], a[(i + 1) % n], b[j], b[(j + 1) % b.length]))
						throw "首版填充不支持相交或接触的多个轮廓";
				if (contains(a, b[0]) || contains(b, a[0]))
					throw "首版填充不支持孔洞或嵌套轮廓，请分开绘制";
			}
		}
		// 完成全部校验后生成网格；失败时不会部分提交到 Graphics。
		for (entry in rings) {
			var ring = entry.points;
			var area = 0.;
			for (i in 0...ring.length) {
				var a = ring[i], b = ring[(i + 1) % ring.length];
				area += a.x * b.y - b.x * a.y;
			}
			if (Math.abs(area) <= EPS) continue;
			var offset = Std.int(mesh.vertices.length / 2);
			for (p in ring) {
				mesh.addVertex(entry.x + p.x * entry.scale, entry.y + p.y * entry.scale);
				mesh.uvs[mesh.uvs.length - 2] = p.x;
				mesh.uvs[mesh.uvs.length - 1] = p.y;
			}
			var remaining = [for (i in 0...ring.length) i];
			var sign = area > 0 ? 1. : -1.;
			while (remaining.length > 3) {
				var found = false;
				for (i in 0...remaining.length) {
					var a = remaining[(i + remaining.length - 1) % remaining.length];
					var b = remaining[i], c = remaining[(i + 1) % remaining.length];
					if (cross(ring[a], ring[b], ring[c]) * sign <= EPS) continue;
					var occupied = false;
					for (p in remaining) {
						if (p == a || p == b || p == c) continue;
						if (cross(ring[a], ring[b], ring[p]) * sign >= -EPS
							&& cross(ring[b], ring[c], ring[p]) * sign >= -EPS
							&& cross(ring[c], ring[a], ring[p]) * sign >= -EPS) {
							occupied = true;
							break;
						}
					}
					if (occupied) continue;
					mesh.triangle(offset + a, offset + b, offset + c);
					remaining.splice(i, 1);
					found = true;
					break;
				}
				if (!found) throw "路径存在无法三角化的退化边，请调整轮廓或增大细分误差";
			}
			if (cross(ring[remaining[0]], ring[remaining[1]], ring[remaining[2]]) * sign <= EPS)
				throw "路径的最后一个三角形退化，请调整轮廓";
			mesh.triangle(offset + remaining[0], offset + remaining[1], offset + remaining[2]);
		}
		return mesh;
	}

	private static function cleanRing(points:Array<Point>):Array<Point> {
		var result:Array<Point> = [];
		for (p in points) if (result.length == 0 || !near(result[result.length - 1], p)) result.push(p);
		if (result.length > 1 && near(result[0], result[result.length - 1])) result.pop();
		var changed = true;
		while (changed && result.length >= 3) {
			changed = false;
			for (i in 0...result.length) {
				var a = result[(i + result.length - 1) % result.length], b = result[i], c = result[(i + 1) % result.length];
				if (Math.abs(cross(a, b, c)) <= EPS && between(a, c, b)) {
					result.splice(i, 1);
					changed = true;
					break;
				}
			}
		}
		return result;
	}

	private static function near(a:Point, b:Point):Bool {
		return Math.abs(a.x - b.x) <= EPS && Math.abs(a.y - b.y) <= EPS;
	}

	private static function cross(a:Point, b:Point, c:Point):Float {
		return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
	}

	private static function between(a:Point, b:Point, p:Point):Bool {
		return p.x >= Math.min(a.x, b.x) - EPS && p.x <= Math.max(a.x, b.x) + EPS
			&& p.y >= Math.min(a.y, b.y) - EPS && p.y <= Math.max(a.y, b.y) + EPS;
	}

	private static function intersects(a:Point, b:Point, c:Point, d:Point):Bool {
		var abc = cross(a, b, c), abd = cross(a, b, d), cda = cross(c, d, a), cdb = cross(c, d, b);
		if (((abc > EPS && abd < -EPS) || (abc < -EPS && abd > EPS))
			&& ((cda > EPS && cdb < -EPS) || (cda < -EPS && cdb > EPS))) return true;
		return (Math.abs(abc) <= EPS && between(a, b, c)) || (Math.abs(abd) <= EPS && between(a, b, d))
			|| (Math.abs(cda) <= EPS && between(c, d, a)) || (Math.abs(cdb) <= EPS && between(c, d, b));
	}

	private static function contains(ring:Array<Point>, p:Point):Bool {
		var inside = false;
		for (i in 0...ring.length) {
			var a = ring[i], b = ring[(i + 1) % ring.length];
			if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x)
				inside = !inside;
		}
		return inside;
	}

	/** 按相邻线段共享的截面生成描边，避免普通转角处重复覆盖。 */
	public static function stroke(contours:Array<PathContour>, width:Float, style:GraphicsStrokeStyle, tolerance:Float):GraphicsMesh {
		var mesh = new GraphicsMesh();
		if (width == 0) return mesh;
		var half = width * 0.5;
		for (contour in contours) {
			var points:Array<Point> = [];
			for (p in contour.points) {
				if (points.length == 0 || p.x != points[points.length - 1].x || p.y != points[points.length - 1].y)
					points.push(p);
			}
			if (contour.closed && points.length > 1 && near(points[0], points[points.length - 1])) points.pop();
			if (points.length < 2) continue;
			var closed = contour.closed && points.length > 2;
			var count = closed ? points.length : points.length - 1;
			var segments:Array<StrokeSegment> = [];
			for (i in 0...count) segments.push(new StrokeSegment(points[i], points[(i + 1) % points.length], half));
			for (i in 0...points.length) {
				if (!closed && (i == 0 || i == points.length - 1)) continue;
				join(mesh, segments[(i + count - 1) % count], segments[i % count], points[i], half, style, tolerance);
			}
			if (!closed && style.cap == SQUARE) {
				var first = segments[0], last = segments[count - 1];
				first.startLeft.x -= first.dx * half; first.startLeft.y -= first.dy * half;
				first.startRight.x -= first.dx * half; first.startRight.y -= first.dy * half;
				last.endLeft.x += last.dx * half; last.endLeft.y += last.dy * half;
				last.endRight.x += last.dx * half; last.endRight.y += last.dy * half;
			}
			for (s in segments) {
				var a = mesh.addVertex(s.startLeft.x, s.startLeft.y), b = mesh.addVertex(s.startRight.x, s.startRight.y);
				var c = mesh.addVertex(s.endLeft.x, s.endLeft.y), d = mesh.addVertex(s.endRight.x, s.endRight.y);
				mesh.triangle(a, b, c); mesh.triangle(b, d, c);
			}
			if (!closed && style.cap == ROUND) {
				var first = segments[0], last = segments[count - 1];
				fan(mesh, points[0], points[0], half, Math.atan2(first.dy, first.dx) + Math.PI / 2, Math.PI, tolerance);
				fan(mesh, points[points.length - 1], points[points.length - 1], half,
					Math.atan2(last.dy, last.dx) - Math.PI / 2, Math.PI, tolerance);
			}
		}
		return mesh;
	}

	private static function join(mesh:GraphicsMesh, previous:StrokeSegment, next:StrokeSegment, p:Point, half:Float,
			style:GraphicsStrokeStyle, tolerance:Float):Void {
		var turn = previous.dx * next.dy - previous.dy * next.dx;
		var dot = Math.max(-1, Math.min(1, previous.dx * next.dx + previous.dy * next.dy));
		if (Math.abs(turn) <= EPS) {
			// 共线同向无需补片；完全折返保留两个平头，交叠按普通混合规则处理。
			return;
		}
		var leftTurn = turn > 0;
		var side = leftTurn ? 1. : -1.;
		var nx = -previous.dy - next.dy, ny = previous.dx + next.dx;
		var factor = half / (1 + dot);
		var mx = nx * factor, my = ny * factor;
		var ratio = Math.sqrt(mx * mx + my * my) / half;
		if (!Math.isFinite(ratio)) {
			// 接近完全折返时，禁止把无穷远交点写入顶点数据。
			mx = my = 0;
			ratio = Math.POSITIVE_INFINITY;
		}
		var ix = mx * side, iy = my * side;
		// 短线段限制内侧交点，避免截面穿越相邻转角，造成翻面和尖刺。
		var projection = Math.max(Math.abs(ix * previous.dx + iy * previous.dy), Math.abs(ix * next.dx + iy * next.dy));
		var limit = Math.min(previous.length, next.length) * 0.5;
		if (projection > limit) { ix *= limit / projection; iy *= limit / projection; }
		var inner = new Point(p.x + ix, p.y + iy);
		if (leftTurn) { previous.endLeft = inner; next.startLeft = inner; }
		else { previous.endRight = inner; next.startRight = inner; }
		if (style.join == MITER && ratio <= style.miterLimit) {
			var outer = new Point(p.x - mx * side, p.y - my * side);
			if (leftTurn) { previous.endRight = outer; next.startRight = outer; }
			else { previous.endLeft = outer; next.startLeft = outer; }
			return;
		}
		var a = leftTurn ? previous.endRight : previous.endLeft;
		var b = leftTurn ? next.startRight : next.startLeft;
		if (style.join == ROUND) {
			fan(mesh, inner, p, half, Math.atan2(a.y - p.y, a.x - p.x), Math.atan2(turn, dot), tolerance);
		} else {
			mesh.triangle(mesh.addVertex(inner.x, inner.y), mesh.addVertex(a.x, a.y), mesh.addVertex(b.x, b.y));
		}
	}

	private static function fan(mesh:GraphicsMesh, origin:Point, center:Point, radius:Float, angle:Float, sweep:Float, tolerance:Float):Void {
		var count = arcSteps(radius, Math.abs(sweep), tolerance);
		var o = mesh.addVertex(origin.x, origin.y);
		var previous = mesh.addVertex(center.x + Math.cos(angle) * radius, center.y + Math.sin(angle) * radius);
		for (i in 1...count + 1) {
			var a = angle + sweep * i / count;
			var next = mesh.addVertex(center.x + Math.cos(a) * radius, center.y + Math.sin(a) * radius);
			mesh.triangle(o, previous, next);
			previous = next;
		}
	}
}

private typedef FillRing = {
	var points:Array<Point>;
	var x:Float;
	var y:Float;
	var maxX:Float;
	var maxY:Float;
	var scale:Float;
}

private class StrokeSegment {
	public var dx:Float;
	public var dy:Float;
	public var length:Float;
	public var startLeft:Point;
	public var startRight:Point;
	public var endLeft:Point;
	public var endRight:Point;

	public function new(a:Point, b:Point, half:Float) {
		dx = b.x - a.x; dy = b.y - a.y;
		length = Math.sqrt(dx * dx + dy * dy);
		if (!Math.isFinite(length) || length == 0) throw "描边线段长度超出了有效数值范围";
		dx /= length; dy /= length;
		var nx = -dy * half, ny = dx * half;
		startLeft = new Point(a.x + nx, a.y + ny); startRight = new Point(a.x - nx, a.y - ny);
		endLeft = new Point(b.x + nx, b.y + ny); endRight = new Point(b.x - nx, b.y - ny);
	}
}
