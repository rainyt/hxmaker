package hx.display.graphics;

import hx.display.graphics.GraphicsPath.PathContour;
import hx.geom.Point;

/** 旧式 lineTo 的增量描边数据，仅重算最后一个转角，避免长折线反复重建。 */
@:noCompletion
class GraphicsLineBuilder {
	public var mesh(default, null):GraphicsMesh = new GraphicsMesh();
	private var previous:Point;
	private var current:Point;
	private var width:Float;
	private var style:GraphicsStrokeStyle;
	private var lastQuadOffset:Int = 0;
	private var pointCount:Int = 1;

	public function new(x:Float, y:Float, width:Float, smoothing:Bool) {
		current = new Point(x, y);
		this.width = width;
		style = new GraphicsStrokeStyle(BUTT, smoothing ? BEVEL : MITER);
	}

	/** 先在临时网格完成计算与容量校验，再更新已提交网格。 */
	public function append(x:Float, y:Float):Void {
		if (pointCount >= 16384) throw "连续折线超过了 16384 个点，请用 moveTo 拆分";
		var next = new Point(x, y);
		var contour = new PathContour();
		contour.points = previous == null ? [current, next] : [previous, current, next];
		var local = PathGeometry.stroke([contour], width, style, 0.25);
		var prefix = Std.int(local.vertices.length / 2) - (previous == null ? 4 : 8);
		var added = prefix + 4;
		var offset = Std.int(mesh.vertices.length / 2);
		if (offset + added > 65535) throw "连续折线超过了网格顶点限制，请用 moveTo 拆分";
		// 局部网格先存转角补片，再存两个线段的四边形。
		for (i in 0...prefix) mesh.addVertex(local.vertices[i * 2], local.vertices[i * 2 + 1]);
		var quad = (prefix + (previous == null ? 0 : 4)) * 2;
		var newQuadOffset = mesh.vertices.length;
		for (i in 0...4) mesh.addVertex(local.vertices[quad + i * 2], local.vertices[quad + i * 2 + 1]);
		if (previous != null) {
			// 前一段只改变终点截面，起点已与更早的转角连接，必须保留。
			for (i in 0...4) mesh.vertices[lastQuadOffset + 4 + i] = local.vertices[prefix * 2 + 4 + i];
			var joinIndices = local.indices.length - 12;
			for (i in 0...Std.int(joinIndices / 3))
				mesh.triangle(offset + local.indices[i * 3], offset + local.indices[i * 3 + 1], offset + local.indices[i * 3 + 2]);
		}
		var a = offset + prefix;
		mesh.triangle(a, a + 1, a + 2);
		mesh.triangle(a + 1, a + 3, a + 2);
		lastQuadOffset = newQuadOffset;
		previous = current;
		current = next;
		pointCount++;
	}
}
