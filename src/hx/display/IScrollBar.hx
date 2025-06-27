package hx.display;

interface IScrollBar extends IRange {
	public function measure(isScroll:Bool = false):Void;

	public var scroll:Scroll;
}
