package hx.display;

import hx.gemo.ColorTransform;
import hx.display.BitmapData;

/**
 * 图形绘制数据
 */
class GraphicsDrawData {
	/**
	 * 渲染命令列表
	 */
	public var draws:Array<Draw> = [];

	/**
	 * 当前绘制命令索引
	 */
	public var index:Int = 0;

	/**
	 * 当前使用的位图
	 */
	public var currentBitmapData:BitmapData;

	/**
	 * 平滑选项
	 */
	public var smoothing:Bool;

	public function new() {}
}

enum Draw {
	/**
	 * 填充的颜色
	 */
	BEGIN_FILL(color:UInt);

	/**
	 * 准备位图
	 */
	BEGIN_BITMAP_DATA(bitmapData:BitmapData, smoothing:Bool);

	/**
	 * 渲染三角形
	 */
	DRAW_TRIANGLE(vertices:Array<Float>, indices:Array<Int>, uvs:Array<Float>, alpha:Float, colorTransform:ColorTransform);
}
