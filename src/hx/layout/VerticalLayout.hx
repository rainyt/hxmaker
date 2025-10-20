package hx.layout;

import hx.display.HorizontalAlign;
import hx.display.DisplayObject;

/**
 * 竖向布局
 */
class VerticalLayout extends Layout {
	public var gap:Float = 0;

	/**
	 * 对齐方式
	 */
	public var horizontalAlign:HorizontalAlign = null;

	/**
	 * 垂直填充，是否等比例填充父容器宽度，默认`false`
	 */
	public var horizontalFill:Bool = false;

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		var offestY:Float = 0;
		var width:Float = parent.width;
		for (object in children) {
			if (@:privateAccess parent.__width != null)
				object.width = width;
			object.y = offestY;
			offestY += object.height + gap;

			if (horizontalFill) {
				object.width = this.parent.width;
			}

			switch (horizontalAlign) {
				case LEFT:
					object.x = 0;
				case CENTER:
					object.x = (this.parent.width - object.width) / 2;
				case RIGHT:
					object.x = this.parent.width - object.height;
			}
		}
	}

	public function setGap(gap:Float) {
		this.gap = gap;
		return this;
	}
}
