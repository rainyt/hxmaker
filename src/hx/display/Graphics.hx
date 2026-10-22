package hx.display;

import hx.display.graphics.GraphicsMesh;
import hx.display.graphics.GraphicsDrawData;
import hx.display.graphics.GraphicsLineBuilder;
import hx.display.graphics.GraphicsPath;
import hx.display.graphics.GraphicsStrokeStyle;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.geom.ColorTransform;
import hx.utils.ColorUtils;

/**
 * 二维图形绘制入口，支持三角形、基础形状和可复用路径。
 * 路径及描边数据类型位于 hx.display.graphics 包。
 */
class Graphics extends DisplayObject {
	private var __beginFill:Null<Int> = null;
	private var __bitmapData:BitmapData;
	private var __bitmapSmoothing:Bool = true;
	@:noCompletion private var __sizeDirty:Bool = false;
	@:noCompletion private var __sizeRect:Rectangle = new Rectangle();
	private var __graphicsDrawData:GraphicsDrawData = new GraphicsDrawData();
	private var __hasRecordedMaterial:Bool = false;
	private var __recordedBitmap:BitmapData;
	private var __recordedSmoothing:Bool = true;
	private var __recordedFill:Int = 0xffffff;
	private var __lineSize:Float = 1;
	private var __lineColor:Null<Int> = null;
	private var __posX:Float = 0;
	private var __posY:Float = 0;
	private var __lineBuilder:GraphicsLineBuilder;
	private var __lineRunAlpha:Float = 1;
	private var __lineRunSmoothing:Bool = true;
	private var __lineRunColor:Int = 0;

	/** 设置后续基础形状的纯色填充，不改变已设置的描边颜色。 */
	public function beginFill(color:Int):Void {
		__beginFill = color;
		__bitmapData = null;
		__resetLineRun();
	}

	/** 设置后续基础形状的位图填充。 */
	public function beginBitmapData(bitmapData:BitmapData, smoothing:Bool = true):Void {
		if (bitmapData == null) throw "位图填充不能为空";
		__bitmapData = bitmapData;
		__bitmapSmoothing = smoothing;
		__beginFill = null;
		__resetLineRun();
	}

	/**
	 * 提交三角形，保留数组和颜色变换引用以兼容 Spine 等动态网格。
	 * 提交后修改引用数据需自行调用 invalidate()；普通路径接口采用提交时快照。
	 * 顶点和 UV 按 x/y、u/v 成对存放，索引必须组成完整三角形。
	 */
	public function drawTriangles(vertices:Array<Float>, indices:Array<Int>, uvs:Array<Float>, alpha:Float = 1,
			?colorTransform:ColorTransform, applyBlendAddMode:Bool = false):Void {
		alpha = __normalizeAlpha(alpha);
		if (vertices == null || indices == null || uvs == null) throw "三角形的顶点、索引和 UV 数组不能为空";
		if (vertices.length % 2 != 0 || indices.length % 3 != 0) throw "顶点必须成对，索引必须组成完整三角形";
		if (vertices.length == 0 && indices.length == 0) return;
		if (uvs.length < vertices.length || uvs.length % 2 != 0) throw "UV 数量不足或没有成对存放";
		for (value in vertices) if (!Math.isFinite(value)) throw "三角形顶点必须是有限数值";
		for (value in uvs) if (!Math.isFinite(value)) throw "三角形 UV 必须是有限数值";
		var count = Std.int(vertices.length / 2);
		for (index in indices) if (index < 0 || index >= count) throw "三角形顶点索引越界";
		__validateColorTransform(colorTransform);
		if (indices.length == 0) return;
		if (colorTransform == null && __beginFill != null) colorTransform = __makeColor(__beginFill);
		__resetLineRun();
		__recordMaterial(__bitmapData, __bitmapSmoothing, __beginFill == null ? 0xffffff : __beginFill);
		__graphicsDrawData.draws.push(DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode));
		__geometryChanged();
	}

	/** 渲染矩形；负宽高表示向相反方向延伸。 */
	public function drawRect(x:Float, y:Float, width:Float, height:Float, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		__validateRect(x, y, width, height);
		if (width == 0 || height == 0) return;
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3],
			[0, 0, 1, 0, 0, 1, 1, 1], alpha, colorTransform);
	}

	/** 设置独立的描边颜色和宽度；线宽为零时不绘制。 */
	public function beginLineStyle(color:UInt, line:Float):Void {
		if (!Math.isFinite(line) || line < 0) throw "线宽必须是非负有限数值";
		__lineColor = color;
		__lineSize = line;
		__resetLineRun();
	}

	/** 移动画笔并开始新的开放折线。 */
	public function moveTo(x:Float, y:Float):Void {
		__validatePoint(x, y);
		__posX = x;
		__posY = y;
		__resetLineRun();
	}

	/**
	 * 延续开放折线。smoothing 为 true 时使用削角，为 false 时使用受限斜接。
	 * 同样式连续线段共享转角网格；修改样式或插入其他绘图会开始新的描边段。
	 */
	public function lineTo(x:Float, y:Float, smoothing:Bool = true, alpha:Float = 1):Void {
		__validatePoint(x, y);
		alpha = __normalizeAlpha(alpha);
		if (x == __posX && y == __posY) return;
		if (__lineSize == 0) { moveTo(x, y); return; }
		var color = __strokeColor();
		var continued = __lineBuilder != null && __lineRunAlpha == alpha && __lineRunSmoothing == smoothing && __lineRunColor == color;
		var builder = continued ? __lineBuilder : new GraphicsLineBuilder(__posX, __posY, __lineSize, smoothing);
		builder.append(x, y);
		if (continued) {
			__geometryChanged();
		} else {
			__submitSolid(builder.mesh, color, alpha, __makeColor(color));
		}
		__lineBuilder = builder;
		__lineRunAlpha = alpha;
		__lineRunSmoothing = smoothing;
		__lineRunColor = color;
		__posX = x;
		__posY = y;
	}

	/** 绘制独立线段，不移动画笔。 */
	public function drawLine(x1:Float, y1:Float, x2:Float, y2:Float, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		var path = new GraphicsPath().moveTo(x1, y1).lineTo(x2, y2);
		__drawStroke(path, __lineSize, alpha, colorTransform);
	}

	/** 按给定纹理尺寸计算矩形 UV；纹理宽高必须大于零。 */
	public function drawRectMask(x:Float, y:Float, width:Float, height:Float, textureWidth:Float, textureHeight:Float, alpha:Float = 1,
			?colorTransform:ColorTransform):Void {
		__validateRect(x, y, width, height);
		if (!Math.isFinite(textureWidth) || !Math.isFinite(textureHeight) || textureWidth <= 0 || textureHeight <= 0)
			throw "纹理宽高必须是大于零的有限数值";
		if (width == 0 || height == 0) return;
		drawRectUVs(x, y, width, height, [x / textureWidth, y / textureHeight, (x + width) / textureWidth, y / textureHeight,
			x / textureWidth, (y + height) / textureHeight, (x + width) / textureWidth, (y + height) / textureHeight], alpha, colorTransform);
	}

	/** 使用自定义 UV 渲染矩形。 */
	public function drawRectUVs(x:Float, y:Float, width:Float, height:Float, uvs:Array<Float>, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		__validateRect(x, y, width, height);
		if (width == 0 || height == 0) return;
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3], uvs, alpha, colorTransform);
	}

	/**
	 * 填充简单凹多边形路径，开放轮廓隐式闭合。
	 * 多个轮廓只支持彼此分离的图形；孔洞、嵌套和自交会明确报错。
	 * tolerance 为本地坐标的细分误差；提交不改变当前填充和描边样式。
	 */
	public function fillPath(path:GraphicsPath, color:Int = 0xffffff, alpha:Float = 1, tolerance:Float = 0.25):Void {
		if (path == null) throw "填充路径不能为空";
		alpha = __normalizeAlpha(alpha);
		var mesh = path.getFillMesh(tolerance);
		__submitSolid(mesh, color, alpha, __makeColor(color));
	}

	/**
	 * 绘制路径描边，支持端点、转角和斜接限制，样式取提交时的值。
	 * 自交和完全折返路径允许绘制，重叠区域按正常透明度混合。
	 */
	public function strokePath(path:GraphicsPath, color:Int = 0x000000, width:Float = 1, alpha:Float = 1,
			?style:GraphicsStrokeStyle, tolerance:Float = 0.25):Void {
		if (path == null) throw "描边路径不能为空";
		if (!Math.isFinite(width) || width < 0) throw "线宽必须是非负有限数值";
		alpha = __normalizeAlpha(alpha);
		if (style == null) style = new GraphicsStrokeStyle();
		style.validate();
		var mesh = path.getStrokeMesh(width, style, tolerance);
		__submitSolid(mesh, color, alpha, __makeColor(color));
	}

	/** 绘制圆形描边；smooth 保留旧接口的细分密度语义。 */
	public function drawCircleLine(x:Float, y:Float, radius:Float, smooth:Int = 10, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		__validatePoint(x, y);
		var steps = __circleSteps(radius, smooth);
		if (steps == 0) return;
		var path = new GraphicsPath();
		for (i in 0...steps) {
			var angle = Math.PI * 2 * i / steps;
			var px = x + Math.cos(angle) * radius, py = y + Math.sin(angle) * radius;
			if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
		}
		path.closePath();
		__drawStroke(path, __lineSize, alpha, colorTransform);
	}

	/** 绘制实心圆，支持位图填充；半径为零时跳过。 */
	public function drawCircle(x:Float, y:Float, radius:Float, smooth:Int = 10, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		__validatePoint(x, y);
		var steps = __circleSteps(radius, smooth);
		if (steps == 0) return;
		var vertices:Array<Float> = [x, y], uvs:Array<Float> = [0.5, 0.5];
		var indices:Array<Int> = [];
		for (i in 0...steps) {
			var angle = Math.PI * 2 * i / steps;
			var cos = Math.cos(angle), sin = Math.sin(angle);
			vertices.push(x + cos * radius); vertices.push(y + sin * radius);
			uvs.push(0.5 + cos * 0.5); uvs.push(0.5 + sin * 0.5);
			indices.push(0); indices.push(i + 1); indices.push((i + 1) % steps + 1);
		}
		drawTriangles(vertices, indices, uvs, alpha, colorTransform);
	}

	/** 绘制点集，默认保留旧接口的闭合行为；closed=false 时绘制开放折线。 */
	public function drawLines(lines:Array<Point>, alpha:Float = 1, ?color:ColorTransform, closed:Bool = true):Void {
		if (lines == null) throw "折线点集不能为空";
		var path = new GraphicsPath();
		for (i in 0...lines.length) {
			var p = lines[i];
			if (p == null) throw "折线点不能为空";
			if (i == 0) path.moveTo(p.x, p.y); else path.lineTo(p.x, p.y);
		}
		if (closed && lines.length > 2) path.closePath();
		__drawStroke(path, __lineSize, alpha, color);
	}

	/** 清空图形、渲染游标、填充、描边及画笔状态，并通知舞台刷新。 */
	public function clear():Void {
		__graphicsDrawData.draws = [];
		__graphicsDrawData.index = 0;
		__graphicsDrawData.currentBitmapData = null;
		__graphicsDrawData.smoothing = true;
		__hasRecordedMaterial = false;
		__recordedBitmap = null;
		__beginFill = null;
		__bitmapData = null;
		__bitmapSmoothing = true;
		__lineColor = null;
		__lineSize = 1;
		__posX = __posY = 0;
		__resetLineRun();
		__geometryChanged();
	}

	/** 外部修改低层网格后，也要使尺寸缓存失效。普通变换不重新扫描顶点。 */
	override public function invalidate():Void {
		__geometryChanged();
	}

	override function __getRect():Rectangle {
		if (__sizeDirty) {
			var minX = Math.POSITIVE_INFINITY, minY = Math.POSITIVE_INFINITY;
			var maxX = Math.NEGATIVE_INFINITY, maxY = Math.NEGATIVE_INFINITY;
			var found = false;
			for (draw in __graphicsDrawData.draws) switch draw {
				case DRAW_TRIANGLE(vertices, indices, _, _, _, _):
					// 仅统计真正被三角形引用的顶点，不让未使用顶点扩大点击范围。
					for (index in indices) {
						if (index < 0 || index >= Std.int(vertices.length / 2)) continue;
						var offset = index * 2;
						var x = vertices[offset], y = vertices[offset + 1];
						if (!Math.isFinite(x) || !Math.isFinite(y)) continue;
						minX = Math.min(minX, x); minY = Math.min(minY, y);
						maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
						found = true;
					}
				default:
			}
			if (found) __sizeRect.setTo(minX, minY, maxX - minX, maxY - minY);
			else __sizeRect.setTo(0, 0, 0, 0);
			__sizeDirty = false;
		}
		return __sizeRect;
	}

	// 保留 Quad 与渲染后端使用的延迟更新钩子。
	private var __graphicsDirty:Bool = false;
	private function updateGraphics():Void {
		__graphicsDirty = false;
	}

	private function __drawStroke(path:GraphicsPath, width:Float, alpha:Float, transform:ColorTransform):Void {
		alpha = __normalizeAlpha(alpha);
		__validateColorTransform(transform);
		var color = __strokeColor();
		var mesh = path.getStrokeMesh(width, new GraphicsStrokeStyle(BUTT, BEVEL), 0.25);
		__submitSolid(mesh, color, alpha, transform == null ? __makeColor(color) : transform);
	}

	private function __submitSolid(mesh:GraphicsMesh, color:Int, alpha:Float, transform:ColorTransform):Void {
		if (mesh.indices.length == 0) return;
		__resetLineRun();
		__recordMaterial(null, true, color);
		__graphicsDrawData.draws.push(DRAW_TRIANGLE(mesh.vertices, mesh.indices, mesh.uvs, alpha, transform, false));
		__geometryChanged();
	}

	/** 相邻绘制使用同一材质时不重复记录切换命令。 */
	private function __recordMaterial(bitmapData:BitmapData, smoothing:Bool, color:Int):Void {
		if (__hasRecordedMaterial && __recordedBitmap == bitmapData) {
			if (bitmapData != null && __recordedSmoothing == smoothing) return;
			if (bitmapData == null && __recordedFill == color) return;
		}
		if (bitmapData == null) __graphicsDrawData.draws.push(BEGIN_FILL(color));
		else __graphicsDrawData.draws.push(BEGIN_BITMAP_DATA(bitmapData, smoothing));
		__hasRecordedMaterial = true;
		__recordedBitmap = bitmapData;
		__recordedSmoothing = smoothing;
		__recordedFill = color;
	}

	private function __resetLineRun():Void {
		__lineBuilder = null;
	}

	private function __strokeColor():Int {
		return __lineColor != null ? __lineColor : (__beginFill != null ? __beginFill : 0x000000);
	}

	private function __geometryChanged():Void {
		__sizeDirty = true;
		setTransformDirty();
		setFilterDirty();
		if (__parent != null) {
			@:privateAccess __parent.__layoutDirty = true;
		}
	}

	private static function __makeColor(value:Int):ColorTransform {
		var color = ColorUtils.toShaderColor(value);
		return new ColorTransform(color.r, color.g, color.b, 1);
	}

	private static function __normalizeAlpha(alpha:Float):Float {
		if (!Math.isFinite(alpha)) throw "透明度必须是有限数值";
		return Math.max(0, Math.min(1, alpha));
	}

	private static function __validatePoint(x:Float, y:Float):Void {
		if (!Math.isFinite(x) || !Math.isFinite(y)) throw "绘图坐标必须是有限数值";
	}

	private static function __validateRect(x:Float, y:Float, width:Float, height:Float):Void {
		__validatePoint(x, y);
		__validatePoint(width, height);
	}

	private static function __validateColorTransform(transform:ColorTransform):Void {
		if (transform == null) return;
		for (value in [transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, transform.alphaMultiplier,
			transform.redOffset, transform.greenOffset, transform.blueOffset, transform.alphaOffset])
			if (!Math.isFinite(value)) throw "颜色变换必须使用有限数值";
	}

	private static function __circleSteps(radius:Float, smooth:Int):Int {
		if (!Math.isFinite(radius) || radius < 0) throw "圆形半径必须是非负有限数值";
		if (smooth <= 0) throw "圆形平滑值必须大于零";
		if (radius == 0) return 0;
		var count = smooth * Math.sqrt(radius);
		if (!Math.isFinite(count) || count > 16384) throw "圆形细分超过了 16384 段，请降低平滑值或改用路径圆弧";
		return Std.int(Math.max(3, count));
	}
}
