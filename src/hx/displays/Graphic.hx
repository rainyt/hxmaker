package hx.displays;

import hx.gemo.ColorTransform;

/**
 * 渲染图形，用于渲染网格三角形使用
 */
class Graphic extends DisplayObject {
	/**
	 * 图形绘制命令数据
	 */
	private var __graphicDrawData:GraphicDrawData = new GraphicDrawData();

	/**
	 * 图形渲染
	 * @param bitmapData 
	 * @param smoothing 
	 */
	public function beginBitmapData(bitmapData:BitmapData, smoothing:Bool = false):Void {
		__graphicDrawData.draws.push(BEGIN_BITMAP_DATA(bitmapData));
	}

	/**
	 * 渲染三角形，这允许分开一次次绘制
	 * @param vertices 坐标顶点
	 * @param indices 顶点索引
	 * @param uvs 纹理坐标
	 * @param alpha 本次绘制的透明度
	 * @param colorTransform 颜色变换
	 */
	public function drawTriangle(vertices:Array<Float>, indices:Array<Int>, uvs:Array<Float>, alpha:Float = 1, ?colorTransform:ColorTransform):Void {
		__graphicDrawData.draws.push(DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform));
	}

	/**
	 * 清理
	 */
	public function clear():Void {
		__graphicDrawData.draws = [];
	}
}
