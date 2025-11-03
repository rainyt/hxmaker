package hx.display;

import hx.geom.Matrix;
import hx.geom.Rectangle;

/**
 * 虚拟盒子容器，设置它的大小不会影响子对象的大小，如果设置了大小，则不会再读取取子对象的大小，会以当前盒子的大小为准
 */
class Box extends DisplayObjectContainer {
	// override function get_width():Float {
	// 	if (__width != null)
	// 		return __width * this.scaleX;
	// 	return super.get_width();
	// }
	// override function get_height():Float {
	// 	if (__height != null)
	// 		return __height * this.scaleY;
	// 	return super.get_height();
	// }
	override function __getRect():Rectangle {
		if (__width != null) {
			__rect.width = __width;
		}
		if (__height != null) {
			__rect.height = __height;
		}
		return super.__getRect();
	}

	override function getBounds(parent:DisplayObject = null):Rectangle {
		var rect = super.getBounds(parent);
		if (__width != null) {
			rect.x = this.x;
			rect.width = __width;
		}
		if (__height != null) {
			rect.y = this.y;
			rect.height = __height;
		}
		return rect;
	}

	override function __getBounds(parent:Matrix = null):Rectangle {
		var rect = super.__getBounds(parent);
		
		var selfRect:Rectangle;
		if (parent != null) {
			var t = __transform.clone();
			t.concat(parent);
			selfRect = __getLocalBounds(__getRect(), t);
		} else {
			selfRect = __getLocalBounds(__getRect());
		}

		if (__width != null) {
			rect.x = selfRect.x;
			rect.width = selfRect.width;
		}
		if (__height != null) {
			rect.y = selfRect.y;
			rect.height = selfRect.height;
		}
		
		return rect;
	}

	public function __superGetBounds(parent:Matrix = null):Rectangle {
		return super.__getBounds(parent);
	}

	override function set_width(value:Float):Float {
		__width = value;
		__layoutDirty = true;
		return value;
	}

	override function set_height(value:Float):Float {
		__height = value;
		__layoutDirty = true;
		return value;
	}
}
