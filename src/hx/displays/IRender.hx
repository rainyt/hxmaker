package hx.displays;

/**
 * 统一的渲染接口实现
 */
interface IRender {
	public function clear():Void;

	public function renderDisplayObjectContainer(container:DisplayObjectContainer):Void;

	public function renderImage(image:Image):Void;

	public function renderLabel(image:Label):Void;

	public function renderQuad(quad:Quad):Void;

	public function endFill():Void;
}
