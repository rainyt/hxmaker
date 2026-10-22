package hx.display.graphics;

import hx.geom.Point;

/**
 * 可复用的二维路径，角度使用弧度。坐标采用显示对象的本地坐标。
 * 修改路径只影响后续提交，已提交到 Graphics 的网格保持原样。
 */
@:allow(hx.display.Graphics)
class GraphicsPath {
	private var commands:Array<PathCommand> = [];
	private var hasCurrent:Bool = false;
	private var currentX:Float = 0;
	private var currentY:Float = 0;
	private var startX:Float = 0;
	private var startY:Float = 0;
	private var cachedTolerance:Float = -1;
	private var cachedContours:Array<PathContour>;
	private var cachedFill:GraphicsMesh;
	private var cachedStroke:GraphicsMesh;
	private var cachedStrokeKey:String;

	public function new() {}

	/** 复制命令，几何缓存不会共享可变状态。 */
	public function clone():GraphicsPath {
		var result = new GraphicsPath();
		result.commands = commands.copy();
		result.hasCurrent = hasCurrent;
		result.currentX = currentX;
		result.currentY = currentY;
		result.startX = startX;
		result.startY = startY;
		return result;
	}

	public function clear():GraphicsPath {
		commands = [];
		hasCurrent = false;
		currentX = currentY = startX = startY = 0;
		changed();
		return this;
	}

	public function moveTo(x:Float, y:Float):GraphicsPath {
		checkPoint(x, y);
		addCommand(MOVE(x, y));
		currentX = startX = x;
		currentY = startY = y;
		hasCurrent = true;
		changed();
		return this;
	}

	/** 空路径上的 lineTo 等价于 moveTo。 */
	public function lineTo(x:Float, y:Float):GraphicsPath {
		checkPoint(x, y);
		if (!hasCurrent)
			return moveTo(x, y);
		addCommand(LINE(x, y));
		currentX = x;
		currentY = y;
		changed();
		return this;
	}

	/** 二次贝塞尔曲线；需先用 moveTo 指定起点。 */
	public function quadraticCurveTo(controlX:Float, controlY:Float, x:Float, y:Float):GraphicsPath {
		checkPoint(controlX, controlY);
		checkPoint(x, y);
		requireCurrent();
		addCommand(QUADRATIC(controlX, controlY, x, y));
		currentX = x;
		currentY = y;
		changed();
		return this;
	}

	/** 三次贝塞尔曲线；需先用 moveTo 指定起点。 */
	public function bezierCurveTo(controlX1:Float, controlY1:Float, controlX2:Float, controlY2:Float, x:Float, y:Float):GraphicsPath {
		checkPoint(controlX1, controlY1);
		checkPoint(controlX2, controlY2);
		checkPoint(x, y);
		requireCurrent();
		addCommand(CUBIC(controlX1, controlY1, controlX2, controlY2, x, y));
		currentX = x;
		currentY = y;
		changed();
		return this;
	}

	/**
	 * 圆弧；屏幕坐标下默认顺时针。已有路径会连接到圆弧起点。
	 * 起止角差绝对值达到一周时绘制完整圆，零半径或零角差不生成圆弧。
	 */
	public function arc(x:Float, y:Float, radius:Float, startAngle:Float, endAngle:Float, anticlockwise:Bool = false):GraphicsPath {
		checkPoint(x, y);
		checkPoint(startAngle, endAngle);
		if (!Math.isFinite(radius) || radius < 0)
			throw "圆弧半径必须是非负有限数值";
		var sweep = endAngle - startAngle;
		if (!Math.isFinite(sweep))
			throw "圆弧角度范围过大";
		var full = Math.PI * 2;
		if (Math.abs(sweep) >= full)
			sweep = anticlockwise ? -full : full;
		else {
			sweep %= full;
			if (anticlockwise && sweep > 0) sweep -= full;
			if (!anticlockwise && sweep < 0) sweep += full;
		}
		var angle = startAngle % full;
		var sx = x + Math.cos(angle) * radius;
		var sy = y + Math.sin(angle) * radius;
		checkPoint(sx, sy);
		var end = Math.abs(sweep) == full ? angle : angle + sweep;
		var ex = x + Math.cos(end) * radius;
		var ey = y + Math.sin(end) * radius;
		checkPoint(ex, ey);
		// 圆弧最多需要连接线和圆弧两条命令，先检查容量以保证失败时不改变路径。
		var required = radius == 0 || sweep == 0 ? 1 : 2;
		if (commands.length + required > 16384) throw "路径命令超过了 16384 条，请拆分路径";
		if (hasCurrent) lineTo(sx, sy); else moveTo(sx, sy);
		if (radius == 0 || sweep == 0)
			return this;
		addCommand(ARC(x, y, radius, angle, sweep));
		currentX = ex;
		currentY = ey;
		changed();
		return this;
	}

	/** 闭合当前子路径；后续 lineTo 从该子路径起点开始新的开放轮廓。 */
	public function closePath():GraphicsPath {
		if (hasCurrent) {
			addCommand(CLOSE);
			currentX = startX;
			currentY = startY;
			changed();
		}
		return this;
	}

	private function requireCurrent():Void {
		if (!hasCurrent) throw "绘制曲线前请先调用 moveTo 指定起点";
	}

	private static function checkPoint(x:Float, y:Float):Void {
		if (!Math.isFinite(x) || !Math.isFinite(y)) throw "路径坐标和角度必须是有限数值";
	}

	private function addCommand(command:PathCommand):Void {
		if (commands.length >= 16384) throw "路径命令超过了 16384 条，请拆分路径";
		commands.push(command);
	}

	private function changed():Void {
		cachedContours = null;
		cachedFill = null;
		cachedStroke = null;
		cachedStrokeKey = null;
	}

	private function getFillMesh(tolerance:Float):GraphicsMesh {
		var contours = flatten(tolerance);
		if (cachedFill == null) cachedFill = PathGeometry.fill(contours);
		return cachedFill;
	}

	private function getStrokeMesh(width:Float, style:GraphicsStrokeStyle, tolerance:Float):GraphicsMesh {
		var contours = flatten(tolerance);
		var key = width + ":" + style.cap + ":" + style.join + ":" + style.miterLimit;
		if (cachedStroke == null || key != cachedStrokeKey) {
			var mesh = PathGeometry.stroke(contours, width, style, tolerance);
			cachedStroke = mesh;
			cachedStrokeKey = key;
		}
		return cachedStroke;
	}

	/** 缓存内部轮廓，调用方不得修改。精度为本地坐标中的最大细分误差。 */
	private function flatten(tolerance:Float):Array<PathContour> {
		if (!Math.isFinite(tolerance) || tolerance <= 0)
			throw "路径细分误差必须是大于零的有限数值";
		if (cachedContours != null && cachedTolerance == tolerance)
			return cachedContours;
		var contours:Array<PathContour> = [];
		var contour:PathContour = null;
		var px = 0., py = 0., sx = 0., sy = 0.;
		var count = 0;
		var append = function(x:Float, y:Float):Void {
			checkPoint(x, y);
			var points = contour.points;
			if (points.length > 0 && points[points.length - 1].x == x && points[points.length - 1].y == y)
				return;
			if (++count > 16384) throw "路径细分超过了 16384 个点，请增大误差或拆分路径";
			points.push(new Point(x, y));
		};
		for (command in commands) {
			switch command {
				case MOVE(x, y):
					contour = new PathContour();
					contours.push(contour);
					px = sx = x;
					py = sy = y;
					append(x, y);
				case CLOSE:
					if (contour != null) contour.closed = true;
					px = sx;
					py = sy;
					contour = null;
				default:
					if (contour == null) {
						contour = new PathContour();
						contours.push(contour);
						sx = px;
						sy = py;
						append(px, py);
					}
					switch command {
						case LINE(x, y):
							append(x, y);
							px = x; py = y;
						case QUADRATIC(cx, cy, x, y):
							// 将二次曲线转为等价三次曲线，复用有界细分算法。
							flattenCubic(px, py, px + (cx - px) * 2 / 3, py + (cy - py) * 2 / 3,
								x + (cx - x) * 2 / 3, y + (cy - y) * 2 / 3, x, y, tolerance, 0, append);
							px = x; py = y;
						case CUBIC(cx1, cy1, cx2, cy2, x, y):
							flattenCubic(px, py, cx1, cy1, cx2, cy2, x, y, tolerance, 0, append);
							px = x; py = y;
						case ARC(x, y, radius, angle, sweep):
							var steps = PathGeometry.arcSteps(radius, Math.abs(sweep), tolerance);
							for (i in 1...steps + 1) {
								// 完整圆的终点复用起始角，避免 sin(2π) 误差产生极短闭合边。
								var a = i == steps && Math.abs(sweep) == Math.PI * 2 ? angle : angle + sweep * i / steps;
								px = x + Math.cos(a) * radius;
								py = y + Math.sin(a) * radius;
								append(px, py);
							}
						default:
					}
			}
		}
		cachedTolerance = tolerance;
		cachedContours = contours;
		cachedFill = null;
		cachedStroke = null;
		return contours;
	}

	private static function flattenCubic(x0:Float, y0:Float, x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float,
			tolerance:Float, depth:Int, append:Float->Float->Void):Void {
		var d1 = distanceToSegment(x1, y1, x0, y0, x3, y3);
		var d2 = distanceToSegment(x2, y2, x0, y0, x3, y3);
		if (!Math.isFinite(d1) || !Math.isFinite(d2)) throw "曲线计算超出了有效数值范围";
		if (d1 <= tolerance && d2 <= tolerance) {
			append(x3, y3);
			return;
		}
		if (depth >= 16) throw "曲线无法在细分深度限制内达到精度，请增大误差或拆分曲线";
		var ax = x0 * 0.5 + x1 * 0.5, ay = y0 * 0.5 + y1 * 0.5;
		var bx = x1 * 0.5 + x2 * 0.5, by = y1 * 0.5 + y2 * 0.5;
		var cx = x2 * 0.5 + x3 * 0.5, cy = y2 * 0.5 + y3 * 0.5;
		var dx = ax * 0.5 + bx * 0.5, dy = ay * 0.5 + by * 0.5;
		var ex = bx * 0.5 + cx * 0.5, ey = by * 0.5 + cy * 0.5;
		var mx = dx * 0.5 + ex * 0.5, my = dy * 0.5 + ey * 0.5;
		flattenCubic(x0, y0, ax, ay, dx, dy, mx, my, tolerance, depth + 1, append);
		flattenCubic(mx, my, ex, ey, cx, cy, x3, y3, tolerance, depth + 1, append);
	}

	private static function distanceToSegment(x:Float, y:Float, ax:Float, ay:Float, bx:Float, by:Float):Float {
		var dx = bx - ax, dy = by - ay;
		var length2 = dx * dx + dy * dy;
		var t = length2 == 0 ? 0 : Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / length2));
		var ex = x - (ax + dx * t), ey = y - (ay + dy * t);
		return Math.sqrt(ex * ex + ey * ey);
	}
}

private enum PathCommand {
	MOVE(x:Float, y:Float);
	LINE(x:Float, y:Float);
	QUADRATIC(cx:Float, cy:Float, x:Float, y:Float);
	CUBIC(cx1:Float, cy1:Float, cx2:Float, cy2:Float, x:Float, y:Float);
	ARC(x:Float, y:Float, radius:Float, angle:Float, sweep:Float);
	CLOSE;
}

/** 路径内部轮廓；开放路径在填充时隐式闭合。 */
@:noCompletion
class PathContour {
	public var points:Array<Point> = [];
	public var closed:Bool = false;
	public function new() {}
}
