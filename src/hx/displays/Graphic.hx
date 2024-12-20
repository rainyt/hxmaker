package hx.displays;

import hx.utils.ColorUtils;
import hx.gemo.ColorTransform;

/**
 * 渲染图形，用于渲染网格三角形使用
 */
class Graphic extends DisplayObject {
	private var __beginFill:Null<Int> = null;

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
	}

	/**
	 * 图形渲染
	 * @param bitmapData 
	 * @param smoothing 
	 */
	public function beginBitmapData(bitmapData:BitmapData, smoothing:Bool = true):Void {
		__graphicDrawData.draws.push(BEGIN_BITMAP_DATA(bitmapData, smoothing));
		__beginFill = null;
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
	}

	/**
	 * 清理
	 */
	public function clear():Void {
		__graphicDrawData.draws = [];
		__beginFill = null;
	}
}
