package hx.display;

import hx.gemo.Rectangle;

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
