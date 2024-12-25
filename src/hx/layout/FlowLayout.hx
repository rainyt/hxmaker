package hx.layout;

import hx.display.DisplayObject;

/**
 * 流布局
 */
class FlowLayout extends Layout {
	/**
	 * 横向间隔
	 */
	public var gapX:Float = 0;

	/**
	 * 竖向间隔
	 */
	public var gapY:Float = 0;

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		if (children.length == 0)
			return;
		var width = children[0].parent.width;
		var offsetX = 0.;
		var offsetY = 0.;
		for (object in children) {
			object.x = offsetX;
			object.y = offsetY;
			offsetX += object.width + gapX;
			if (offsetX > width) {
				offsetX = 0.;
				offsetY += object.height + gapY;
			}
		}
	}
}
