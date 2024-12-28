package hx.display;

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
}
