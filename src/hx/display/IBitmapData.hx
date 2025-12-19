package hx.display;

import hx.geom.Matrix;

/**
 * 纹理接口
 */
interface IBitmapData {
	public function getTexture():Dynamic;

	public function getWidth():Int;

	public function getHeight():Int;

	public function clear():Void;

	/**
	 * 绘制源对象到当前位图数据
	 * @param source 源对象
	 * @param matrix 变换矩阵
	 */
	public function draw(source:DisplayObject, matrix:Matrix):Void;
}
