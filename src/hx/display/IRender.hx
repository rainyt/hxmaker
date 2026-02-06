package hx.display;

/**
 * 统一的渲染接口，定义了渲染系统的核心功能
 * 不同平台的渲染实现都需要实现此接口
 */
interface IRender {
	/**
	 * 是否开启缓存为Bitmap
	 * 开启后可以提高渲染性能，但会增加内存使用。当成功开启后，渲染模式会将画面渲染到缓冲区位图中，它会受到`highDpi`的影响。
	 */
	public var cacheAsBitmap(get, set):Bool;

	/**
	 * 是否开启高分辨率支持
	 * 开启后会根据设备DPI调整渲染精度，该参数会影响`cacheAsBitmap`参数。开启后在绘制的时候会将画面放大后进行渲染，再缩小渲染到缓冲区位图上，从而提高渲染质量。
	 * 如果`cacheAsBitmap`参数为`false`，则`highDpi`参数无效`
	 */
	public var highDpi(get, set):Bool;

	/**
	 * 清理屏幕
	 * 通常在每帧开始时调用，清除上一帧的渲染内容
	 */
	public function clear():Void;

	/**
	 * 渲染显示对象容器
	 * @param container 要渲染的显示对象容器
	 */
	public function renderDisplayObjectContainer(container:DisplayObjectContainer):Void;

	/**
	 * 渲染单个显示对象
	 * @param object 要渲染的显示对象
	 */
	public function renderDisplayObject(object:DisplayObject):Void;

	/**
	 * 渲染图片对象
	 * @param image 要渲染的图片对象
	 */
	public function renderImage(image:Image):Void;

	/**
	 * 渲染文本对象
	 * @param image 要渲染的文本对象
	 * @param offScreenRender 是否进行离屏渲染，离屏后不会直接渲染到画面中
	 */
	public function renderLabel(image:Label, offScreenRender:Bool = false):Void;

	/**
	 * 渲染自定义显示对象
	 * @param displayObject 要渲染的自定义显示对象
	 */
	public function renderCustomDisplayObject(displayObject:CustomDisplayObject):Void;

	/**
	 * 渲染矢量图形对象
	 * @param graphics 要渲染的矢量图形对象
	 */
	public function renderGraphics(graphics:Graphics):Void;

	/**
	 * 将当前已渲染好的画面渲染到BitmapData
	 * @param bitmapData 目标BitmapData对象
	 */
	public function renderToBitmapData(bitmapData:hx.display.BitmapData):Void;

	/**
	 * 结束填充操作
	 * 在渲染矢量图形时使用，标记填充操作的结束
	 */
	public function endFill():Void;
}
