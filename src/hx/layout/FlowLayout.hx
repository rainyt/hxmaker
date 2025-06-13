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

	public function new(gapX:Float = 0, gapY:Float = 0) {
		super();
		this.gapX = gapX;
		this.gapY = gapY;
	}

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		if (children.length == 0)
			return;
		var width = children[0].parent.width;
		var offsetX = 0.;
		var offsetY = 0.;
		var nextOffsetY = 0.;
		for (object in children) {
			object.x = offsetX;
			object.y = offsetY;
			var aX = object.width + gapX;
			var aY = object.height + gapY;
			offsetX += aX;
			if (nextOffsetY < offsetY + aY) {
				nextOffsetY = offsetY + aY;
			}
			if (offsetX + object.width > width) {
				offsetX = 0.;
				offsetY = nextOffsetY;
			}
		}
	}
}
