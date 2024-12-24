package hx.display;

/**
 * 统一的渲染接口实现
 */
interface IRender {
	/**
	 * 清理屏幕
	 */
	public function clear():Void;

	/**
	 * 渲染容器
	 * @param container 
	 */
	public function renderDisplayObjectContainer(container:DisplayObjectContainer):Void;

	/**
	 * 渲染图片
	 * @param image 
	 */
	public function renderImage(image:Image):Void;

	/**
	 * 渲染文本
	 * @param image 
	 * @param offScreenRender 离屏渲染，离屏后，不会渲染到画面中
	 */
	public function renderLabel(image:Label, offScreenRender:Bool = false):Void;

	/**
	 * 渲染自定义对象
	 * @param displayObject 
	 */
	public function renderCustomDisplayObject(displayObject:CustomDisplayObject):Void;

	/**
	 * 渲染三角形图形
	 * @param graphics 
	 */
	public function renderGraphics(graphics:Graphic):Void;

	public function endFill():Void;
}
