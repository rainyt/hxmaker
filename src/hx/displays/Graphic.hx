package hx.displays;

import hx.gemo.Rectangle;
import hx.utils.ColorUtils;
import hx.gemo.ColorTransform;

/**
 * 渲染图形，用于渲染网格三角形使用
 */
class Graphic extends DisplayObject {
	private var __beginFill:Null<Int> = null;

	@:noCompletion private var __sizeDirty:Bool = false;
	@:noCompletion private var __sizeRect:Rectangle = new Rectangle();

	/**
	 * 图形绘制命令数据
	 */
	private var __graphicDrawData:GraphicDrawData = new GraphicDrawData();

	/**
	 * 纯色块渲染
	 * @param color 
	 */
	public function beginFill(color:Int):Void {
		__graphicDrawData.draws.push(BEGIN_FILL(color));
		__beginFill = color;
		__sizeDirty = true;
	}

	/**
	 * 图形渲染
	 * @param bitmapData 
	 * @param smoothing 
	 */
	public function beginBitmapData(bitmapData:BitmapData, smoothing:Bool = true):Void {
		__graphicDrawData.draws.push(BEGIN_BITMAP_DATA(bitmapData, smoothing));
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
		__graphicDrawData.draws.push(DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform));
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

	/**
	 * 渲染矩形，可提供UVs
	 * @param x 坐标x 
	 * @param y 坐标y
	 * @param width 宽度
	 * @param height 高度
	 */
	public function drawRectUVs(x:Float, y:Float, width:Float, height:Float, alpha:Float = 1, uvs:Array<Float>, ?colorTransform:ColorTransform):Void {
		drawTriangles([x, y, x + width, y, x, y + height, x + width, y + height], [0, 1, 2, 1, 2, 3], uvs, alpha, colorTransform);
		__sizeDirty = true;
	}

	/**
	 * 清理
	 */
	public function clear():Void {
		__graphicDrawData.draws = [];
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
			for (draw in this.__graphicDrawData.draws) {
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
