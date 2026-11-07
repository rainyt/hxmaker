package hx.display.graphics;

/**
 * 为纯色路径的轮廓生成向外的覆盖率过渡带，不创建位图、不修改着色器。
 * 输入变换只包含到物理屏幕像素的线性部分，输出仍为本地坐标。
 */
@:noCompletion
class GraphicsAntialiaser {
	public static function build(source:GraphicsMesh, a:Float, b:Float, c:Float, d:Float, width:Float):GraphicsMesh {
		if (source.indices.length == 0 || !Math.isFinite(width) || width <= 0) return source;
		var scale = Math.max(Math.max(Math.abs(a), Math.abs(b)), Math.max(Math.abs(c), Math.abs(d)));
		if (!Math.isFinite(scale) || scale == 0) return source;
		var an = a / scale, bn = b / scale, cn = c / scale, dn = d / scale;
		var determinant = an * dn - bn * cn;
		// 奇异或接近奇异的变换无法稳定反算本地偏移，安全回退到原始网格。
		if (!Math.isFinite(determinant) || Math.abs(determinant) < 1e-12) return source;
		var count = Std.int(source.vertices.length / 2);
		var originX = source.vertices[0], originY = source.vertices[1];
		var xs:Array<Float> = [], ys:Array<Float> = [];
		var minX = Math.POSITIVE_INFINITY, minY = Math.POSITIVE_INFINITY;
		var maxX = Math.NEGATIVE_INFINITY, maxY = Math.NEGATIVE_INFINITY;
		for (i in 0...count) {
			var x = source.vertices[i * 2] - originX, y = source.vertices[i * 2 + 1] - originY;
			var sx = x * a + y * c, sy = x * b + y * d;
			if (!Math.isFinite(sx) || !Math.isFinite(sy)) return source;
			xs.push(sx); ys.push(sy);
			minX = Math.min(minX, sx); maxX = Math.max(maxX, sx);
			minY = Math.min(minY, sy); maxY = Math.max(maxY, sy);
		}
		var extent = Math.max(maxX - minX, maxY - minY);
		if (!Math.isFinite(extent) || extent == 0) return source;
		// 用物理像素容差焊接四边形与圆角补片的重复顶点，不把内部接缝当作轮廓。
		// 限制网格桶编号范围，避免 Haxe 的整数取整溢出。
		var epsilon = Math.max(1e-5, extent / 1e8);
		var epsilon2 = epsilon * epsilon;
		var buckets:Map<String, Array<Int>> = new Map();
		var nodes:Array<AntialiasNode> = [];
		var canonical:Array<Int> = [];
		for (i in 0...count) {
			var gx = Math.floor((xs[i] - minX) / epsilon), gy = Math.floor((ys[i] - minY) / epsilon);
			var found = -1;
			for (ox in -1...2) {
				for (oy in -1...2) {
					var candidates = buckets.get((gx + ox) + ":" + (gy + oy));
					if (candidates == null) continue;
					for (candidate in candidates) {
						var node = nodes[candidate];
						var dx = node.x - xs[i], dy = node.y - ys[i];
						if (dx * dx + dy * dy <= epsilon2) { found = candidate; break; }
					}
					if (found >= 0) break;
				}
				if (found >= 0) break;
			}
			if (found < 0) {
				found = nodes.length;
				nodes.push({x: xs[i], y: ys[i], source: i, outer: -1});
				var key = gx + ":" + gy;
				var bucket = buckets.get(key);
				if (bucket == null) { bucket = []; buckets.set(key, bucket); }
				bucket.push(found);
			}
			canonical.push(found);
		}
		var edges:Map<String, AntialiasEdge> = new Map();
		var manifold = true;
		var addEdge = function(start:Int, end:Int):Void {
			var key = start < end ? start + ":" + end : end + ":" + start;
			var edge = edges.get(key);
			if (edge == null) edges.set(key, {start: start, end: end, count: 1});
			else {
				edge.count++;
				if (edge.count > 2 || edge.start != end || edge.end != start) manifold = false;
			}
		};
		for (i in 0...Std.int(source.indices.length / 3)) {
			var ia = canonical[source.indices[i * 3]], ib = canonical[source.indices[i * 3 + 1]], ic = canonical[source.indices[i * 3 + 2]];
			if (ia == ib || ib == ic || ic == ia) continue;
			var p = nodes[ia], q = nodes[ib], r = nodes[ic];
			var area = (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
			if (!Math.isFinite(area)) return source;
			if (Math.abs(area) <= epsilon2) continue;
			// 将三角形统一为正绕向；镜像变换也能得到朝外的法线。
			if (area < 0) { var temp = ib; ib = ic; ic = temp; }
			addEdge(ia, ib); addEdge(ib, ic); addEdge(ic, ia);
		}
		if (!manifold) return source;
		var incoming:Array<AntialiasEdge> = [], outgoing:Array<AntialiasEdge> = [];
		incoming.resize(nodes.length); outgoing.resize(nodes.length);
		var boundary:Array<AntialiasEdge> = [];
		for (edge in edges) {
			if (edge.count != 1) continue;
			if (outgoing[edge.start] != null || incoming[edge.end] != null) return source;
			outgoing[edge.start] = edge;
			incoming[edge.end] = edge;
			boundary.push(edge);
		}
		if (boundary.length == 0 || count + boundary.length > 65535) return source;
		var result = new GraphicsMesh();
		result.vertices = source.vertices.copy();
		result.indices = source.indices.copy();
		result.uvs = source.uvs.copy();
		result.coverage = [for (_ in 0...count) 1.];
		for (i in 0...nodes.length) {
			var before = incoming[i], after = outgoing[i];
			if (before == null && after == null) continue;
			if (before == null || after == null) return source;
			var node = nodes[i], previous = nodes[before.start], next = nodes[after.end];
			var dx1 = node.x - previous.x, dy1 = node.y - previous.y;
			var dx2 = next.x - node.x, dy2 = next.y - node.y;
			var length1 = Math.sqrt(dx1 * dx1 + dy1 * dy1), length2 = Math.sqrt(dx2 * dx2 + dy2 * dy2);
			if (!Math.isFinite(length1) || !Math.isFinite(length2) || length1 == 0 || length2 == 0) return source;
			var nx1 = dy1 / length1, ny1 = -dx1 / length1, nx2 = dy2 / length2, ny2 = -dx2 / length2;
			var denominator = 1 + nx1 * nx2 + ny1 * ny2;
			var ox:Float, oy:Float;
			if (denominator <= 1e-6) { ox = nx2 * width; oy = ny2 * width; }
			else { ox = (nx1 + nx2) * width / denominator; oy = (ny1 + ny2) * width / denominator; }
			var distance = Math.sqrt(ox * ox + oy * oy);
			if (distance > width * 4) { ox *= width * 4 / distance; oy *= width * 4 / distance; }
			var localX = (dn * ox - cn * oy) / determinant / scale;
			var localY = (-bn * ox + an * oy) / determinant / scale;
			var x = source.vertices[node.source * 2] + localX, y = source.vertices[node.source * 2 + 1] + localY;
			if (!Math.isFinite(x) || !Math.isFinite(y)) return source;
			node.outer = result.addVertex(x, y);
			result.uvs[node.outer * 2] = source.uvs[node.source * 2];
			result.uvs[node.outer * 2 + 1] = source.uvs[node.source * 2 + 1];
			result.coverage.push(0);
		}
		for (edge in boundary) {
			var p = nodes[edge.start], q = nodes[edge.end];
			result.triangle(p.source, p.outer, q.source);
			result.triangle(q.source, p.outer, q.outer);
		}
		return result;
	}
}

private typedef AntialiasNode = {
	var x:Float;
	var y:Float;
	var source:Int;
	var outer:Int;
}

private typedef AntialiasEdge = {
	var start:Int;
	var end:Int;
	var count:Int;
}
