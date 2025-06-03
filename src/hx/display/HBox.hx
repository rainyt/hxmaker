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
}
