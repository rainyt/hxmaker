package hx.providers;

import hx.geom.Rectangle;

/** 文本后端可选的布局接口，提供包含空白字符的边界和插入光标位置。 */
interface ITextFieldLayoutProvider extends ITextFieldDataProvider {
	/** 每次重新构建字符布局后递增，用于刷新缓存。 */
	public var layoutVersion(default, null):Int;

	/** 文本布局边界，返回后端持有的只读矩形。 */
	public function getTextBounds():Rectangle;

	/** 插入位置的边界，包含末尾和换行后的空行。 */
	public function getCaretBounds(index:Int):Rectangle;
}
