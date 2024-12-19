package hx.displays;

import hx.gemo.ColorTransform;
import hx.displays.BitmapData;

/**
 * 图形绘制数据
 */
class GraphicDrawData {
	public var draws:Array<Draw>;

	public function new() {}
}

enum Draw {
	/**
	 * 准备位图
	 */
	BEGIN_BITMAP_DATA(bitampData:BitmapData);

	/**
	 * 渲染三角形
	 */
	DRAW_TRIANGLE(vertices:Array<Float>, indices:Array<Int>, uvs:Array<Float>, alpha:Float, colorTransform:ColorTransform);
}
