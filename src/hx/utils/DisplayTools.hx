package hx.utils;

import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;

/**
 * 显示对象工具
 */
class DisplayTools {
	/**
	 * 遍历容器里的所有对象
	 * @param display 
	 * @param cb 当返回`false`时，则会中断循环
	 */
	public static function map(display:DisplayObjectContainer, cb:DisplayObject->Bool):Bool {
		for (i in 0...display.numChildren) {
			var d = display.getChildAt(i);
			var b = cb(d);
			if (!b)
				return false;
			if (d is DisplayObjectContainer) {
				var b = map(cast d, cb);
				if (!b)
					break;
			}
		}
		return true;
	}
}
