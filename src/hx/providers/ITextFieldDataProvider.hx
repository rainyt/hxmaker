package hx.providers;

import hx.geom.Rectangle;

/**
 * 文本扩展提供数据接口，由底层引擎提供方法实现
 */
interface ITextFieldDataProvider {
	/**
	 * 获得文本宽度
	 * @return Float
	 */
	public function getTextWidth():Float;

	/**
	 * 获得文本高度
	 * @return Float
	 */
	public function getTextHeight():Float;

	/**
	 * 获得文本边界
	 * @param index 
	 * @return Rectangle
	 */
	public function getChatBounds(index:Int):Rectangle;

	/**
	 * 释放文本
	 */
	public function release():Void;
}
