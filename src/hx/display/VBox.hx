package hx.display;

import hx.display.HorizontalAlign;

@:keep
class VBox extends Box {
	override function onInit() {
		super.onInit();
		this.layout = new hx.layout.VerticalLayout();
	}

	/**
	 * 设置间距
	 */
	public var gap(get, set):Float;

	private function set_gap(value:Float):Float {
		cast(this.layout, hx.layout.VerticalLayout).gap = value;
		return value;
	}

	private function get_gap():Float {
		return cast(this.layout, hx.layout.VerticalLayout).gap;
	}

	/**
	 * 水平对齐方式，如果不设置，则由程序自行计算
	 */
	public var horizontalAlign(get, set):HorizontalAlign;

	private function set_horizontalAlign(value:HorizontalAlign):HorizontalAlign {
		cast(this.layout, hx.layout.VerticalLayout).horizontalAlign = value;
		return value;
	}

	private function get_horizontalAlign():HorizontalAlign {
		return cast(this.layout, hx.layout.VerticalLayout).horizontalAlign;
	}

	public var fill(get, set):Bool;

	private function set_fill(value:Bool):Bool {
		cast(this.layout, hx.layout.VerticalLayout).horizontalFill = value;
		return value;
	}

	private function get_fill():Bool {
		return cast(this.layout, hx.layout.VerticalLayout).horizontalFill;
	}
}
