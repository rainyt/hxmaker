package hx.providers;

/**
 * 文本扩展提供数据接口
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
}
