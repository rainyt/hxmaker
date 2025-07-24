package hx.layout;

import hx.display.DisplayObject;

/**
 * 竖向布局
 */
class VerticalLayout extends Layout {
	public var gap:Float = 0;

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		var offestY:Float = 0;
		var width:Float = parent.width;
		for (object in children) {
			if (@:privateAccess parent.__width != null)
				object.width = width;
			object.y = offestY;
			offestY += object.height + gap;
		}
	}

	public function setGap(gap:Float) {
		this.gap = gap;
		return this;
	}
}
