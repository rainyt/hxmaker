package hx.display;

@:keep
class HBox extends Box {
	override function onInit() {
		super.onInit();
		this.layout = new hx.layout.HorizontalLayout();
	}

	/**
	 * 设置间距
	 */
	public var gap(get, set):Float;

	private function set_gap(value:Float):Float {
		cast(this.layout, hx.layout.HorizontalLayout).gap = value;
		return value;
	}

	private function get_gap():Float {
		return cast(this.layout, hx.layout.HorizontalLayout).gap;
	}

	/**
	 * 垂直对齐方式，如果不设置，则由程序自行计算
	 */
	public var verticalAlign(get, set):VerticalAlign;

	private function set_verticalAlign(value:VerticalAlign):VerticalAlign {
		cast(this.layout, hx.layout.HorizontalLayout).verticalAlign = value;
		return value;
	}

	private function get_verticalAlign():VerticalAlign {
		return cast(this.layout, hx.layout.HorizontalLayout).verticalAlign;
	}
}
