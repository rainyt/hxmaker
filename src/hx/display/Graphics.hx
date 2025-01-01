package hx.display;

import hx.gemo.Rectangle;
import hx.utils.ColorUtils;
import hx.gemo.ColorTransform;

/**
 * 渲染图形，用于渲染网格三角形使用
 */
class Graphics extends DisplayObject {
	private var __beginFill:Null<Int> = null;

	@:noCompletion private var __sizeDirty:Bool = false;
	@:noCompletion private var __sizeRect:Rectangle = new Rectangle();

	/**
	 * 图形绘制命令数据
	 */
	private var __graphicsDrawData:GraphicsDrawData = new GraphicsDrawData();

	/**
	 * 纯色块渲染
	 * @param color 
	 */
	public function beginFill(color:Int):Void {
		__graphicsDrawData.draws.push(BEGIN_FILL(color));
		__beginFill = color;
		__sizeDirty = true;
	}

	/**
	 * 图形渲染
	 * @param bitmapData 
	 * @param smoothing 
	 */
	public function beginBitmapData(bitmapData:BitmapData, smoothing:Bool = true):Void {
		__graphicsDrawData.draws.push(BEGIN_BITMAP_DATA(bitmapData, smoothing));
		__beginFill = null;
		__sizeDirty = true;
	}

	/**
	 * 渲染三角形，这允许分开一次次绘制
	 * @param vertices 坐标顶点
	 * @param indices 顶点索引
	 * @param uvs 纹理坐标
	 * @param alpha 本次绘制的透明度
	 * @param colorTransform 颜色变换
	 */
	public function drawTriangles(vertices:Array<Float>, indices:Array<Int>, uvs:Array<Float>, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		if (colorTransform == null && __beginFill != null) {
			var color = ColorUtils.toShaderColor(__beginFill);
			colorTransform = new ColorTransform(color.r, color.g, color.b, 1);
		}
		__graphicsDrawData.draws.push(DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform));
		__sizeDirty = true;
	}

	/**
	 * 渲染矩形
	 * @param x 坐标x 
	 * @param y 坐标y
	 * @param width 宽度
	 * @param height 高度
	 */
	public function drawRect(x:Float, y:Float, width:Float, height:Float, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1], alpha, colorTransform);
		__sizeDirty = true;
	}

	private var __lineSize:Float = 1;

	private var __lineColor:Int = 0x000000;

	/**
	 * 准备线段的颜色长度
	 * @param line 
	 */
	public function beginLineStyle(color:UInt, line:Float):Void {
		this.beginFill(color);
		this.__lineColor = color;
		this.__lineSize = line;
	}

	private var __posX:Float = 0;
	private var __posY:Float = 0;
	private var __lineDrawing = false;
	private var __lastVertices:Array<Float>;

	/**
	 * 移动到指定的坐标进行开始绘制线条
	 * @param x 
	 * @param y 
	 */
	public function moveTo(x:Float, y:Float):Void {
		__posX = x;
		__posY = y;
		__lineDrawing = false;
		__lastVertices = null;
	}

	/**
	 * 开始绘制到指定为止的现象，请注意，多次调用lineTo方法，会补充线段的连接处的断点
	 * @param x 
	 * @param y 
	 */
	public function lineTo(x:Float, y:Float):Void {
		var nextVertices = __mathLine(__posX, __posY, x, y);
		if (__lineDrawing && __lastVertices != null) {
			// 补充断成
			var vertices = [
				__lastVertices[2],
				__lastVertices[3],
				nextVertices[0],
				nextVertices[1],
				__lastVertices[6],
				__lastVertices[7],
				nextVertices[4],
				nextVertices[5]
			];
			this.drawTriangles(vertices, [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1]);
		}
		__lastVertices = nextVertices;
		this.drawTriangles(nextVertices, [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1]);
		__posX = x;
		__posY = y;
		__lineDrawing = true;
	}

	/**
	 * 绘制线段
	 * @param x1 起点坐标x
	 * @param y1 起点坐标y
	 * @param x2 结束坐标x
	 * @param y2 结束坐标y
	 * @param alpha 透明度
	 * @param colorTransform 颜色
	 */
	public function drawLine(x1:Float, y1:Float, x2:Float, y2:Float, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		this.drawTriangles(__mathLine(x1, y1, x2, y2), [0, 1, 2, 1, 2, 3], [0, 0, 1, 0, 0, 1, 1, 1], alpha, colorTransform);
	}

	private function __mathLine(x1:Float, y1:Float, x2:Float, y2:Float):Array<Float> {
		// 计算出线段长度
		var dx = x2 - x1;
		var dy = y2 - y1;
		var length = Math.sqrt(dx * dx + dy * dy);
		// 计算出线段弧度
		var radian = Math.atan2(dy, dx);
		var cos:Float = Math.cos(radian);
		var sin:Float = Math.sin(radian);
		// 绘制线段
		var vertices = [];
		var offsetX1 = x1 + sin * 0.5 * __lineSize;
		var offsetY1 = y1 - cos * 0.5 * __lineSize;
		var offsetX2 = x1 - sin * 0.5 * __lineSize;
		var offsetY2 = y1 + cos * 0.5 * __lineSize;
		vertices.push(offsetX1);
		vertices.push(offsetY1);
		vertices.push(offsetX1 + cos * length);
		vertices.push(offsetY1 + sin * length);
		vertices.push(offsetX2);
		vertices.push(offsetY2);
		vertices.push(offsetX2 + cos * length);
		vertices.push(offsetY2 + sin * length);
		return vertices;
	}

	/**
	 * 渲染矩形，UVs会根据 textureSize计算
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 * @param alpha 
	 * @param colorTransform 
	 */
	public function drawRectMask(x:Float, y:Float, width:Float, height:Float, textureWidth:Float, textureHeight:Float, alpha:Float = 1,
			?colorTransform:ColorTransform):Void {
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3], [
			x / textureWidth,
			y / textureHeight,
			(x + width) / textureWidth,
			y / textureHeight,
			x / textureWidth,
			(y + height) / textureHeight,
			(x + width) / textureWidth,
			(y + height) / textureHeight
		], alpha, colorTransform);
		__sizeDirty = true;
	}

	/**
	 * 渲染矩形，可提供UVs
	 * @param x 坐标x 
	 * @param y 坐标y
	 * @param width 宽度
	 * @param height 高度
	 */
	public function drawRectUVs(x:Float, y:Float, width:Float, height:Float, uvs:Array<Float>, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3], uvs, alpha, colorTransform);
		__sizeDirty = true;
	}

	/**
	 * 清理
	 */
	public function clear():Void {
		__graphicsDrawData.draws = [];
		__beginFill = null;
		__sizeDirty = true;
	}

	override function setTransformDirty(value:Bool = true) {
		super.setTransformDirty(value);
		__sizeDirty = true;
	}

	override function __getRect():Rectangle {
		if (__sizeDirty) {
			// 这里对Graphic的尺寸进行重新测量
			for (draw in this.__graphicsDrawData.draws) {
				switch draw {
					case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform):
						var len = Std.int(vertices.length / 2);
						__sizeRect.setTo(vertices[0], vertices[1], 0, 0);
						for (i in 0...len) {
							var tx = vertices[i * 2];
							var ty = vertices[i * 2 + 1];
							if (tx < __sizeRect.left) {
								__sizeRect.left = tx;
							} else if (tx > __sizeRect.right) {
								__sizeRect.right = tx;
							}
							if (ty < __sizeRect.top) {
								__sizeRect.top = ty;
							} else if (ty > __sizeRect.bottom) {
								__sizeRect.bottom = ty;
							}
						}
					default:
				}
			}
			__sizeDirty = false;
		}
		return __sizeRect;
	}
}
