package hx.display;

import hx.geom.Matrix;

/**
 * 纹理接口
 */
interface IBitmapData {
	/**
	 * 获取纹理对象
	 * @return 纹理对象
	 */
	public function getTexture():Dynamic;

	/**
	 * 获取位图数据宽度
	 * @return 宽度
	 */
	public function getWidth():Int;

	/**
	 * 获取位图数据高度
	 * @return 高度
	 */
	public function getHeight():Int;

	/**
	 * 清除位图数据
	 */
	public function clear():Void;

	/**
	 * 绘制源对象到当前位图数据
	 * @param source 源对象
	 * @param matrix 变换矩阵
	 */
	public function draw(source:DisplayObject, matrix:Matrix, ?blendMode:BlendMode, updateTransform:Bool = true):Void;

	/**
	 * 释放位图数据
	 */
	public function dispose():Void;
}
