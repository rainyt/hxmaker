package hx.layout;

import hx.display.DisplayObject;

/**
 * 横向布局
 */
class HorizontalLayout extends Layout {
	/**
	 * 间距
	 */
	public var gap:Float = 0;

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		var offestX = 0.;
		for (child in children) {
			child.x = offestX;
			offestX += child.width + gap;
		}
	}

	public function setGap(gap:Float) {
		this.gap = gap;
		return this;
	}
}
