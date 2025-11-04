package hx.display;

import hx.layout.FlowLayout;

/**
 * 流布局容器
 */
class FlowBox extends Box {
	/**
	 * 横向间隔
	 */
	public var gapX(get, set):Float;

	private function get_gapX():Float {
		return cast(this.layout, FlowLayout).gapX;
	}

	private function set_gapX(value:Float):Float {
		cast(this.layout, FlowLayout).gapX = value;
		return value;
	}

	/**
	 * 竖向间隔
	 */
	public var gapY(get, set):Float;

	private function get_gapY():Float {
		return cast(this.layout, FlowLayout).gapY;
	}

	private function set_gapY(value:Float):Float {
		cast(this.layout, FlowLayout).gapY = value;
		return value;
	}

	/**
	 * 间距
	 */
	public var gap(never, set):Float;

	private function set_gap(value:Float):Float {
		gapX = value;
		gapY = value;
		return value;
	}

	override function onInit() {
		super.onInit();
		this.layout = new FlowLayout();
	}
}
