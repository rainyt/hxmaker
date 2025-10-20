package hx.layout;

import hx.display.VerticalAlign;
import hx.display.DisplayObject;

/**
 * 横向布局
 */
class HorizontalLayout extends Layout {
	/**
	 * 间距
	 */
	public var gap:Float = 0;

	/**
	 * 对齐方式
	 */
	public var verticalAlign:VerticalAlign = null;

	/**
	 * 垂直填充，是否等比例填充父容器高度，默认`false`
	 */
	public var verticalFill:Bool = false;

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		var offestX = 0.;
		for (child in children) {
			child.x = offestX;
			offestX += child.width + gap;

			if (verticalFill) {
				child.height = this.parent.height;
			}

			switch (verticalAlign) {
				case TOP:
					child.y = 0;
				case MIDDLE:
					child.y = (this.parent.height - child.height) / 2;
				case BOTTOM:
					child.y = this.parent.height - child.height;
			}
		}
	}

	public function setGap(gap:Float) {
		this.gap = gap;
		return this;
	}
}
