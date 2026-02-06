package hx.display;

import hx.geom.Matrix;
import hx.geom.Rectangle;

/**
 * 虚拟盒子容器类
 * 设置它的大小不会影响子对象的大小，如果设置了大小，则不会再读取子对象的大小，会以当前盒子的大小为准
 * 用于布局和组织显示对象，提供了更灵活的尺寸控制
 */
class Box extends DisplayObjectContainer {
	/**
	 * 重写获取矩形边界的方法
	 * 如果设置了宽度或高度，则使用设置的值
	 * @return 计算后的矩形边界
	 */
	override function __getRect():Rectangle {
		if (__width != null) {
			__rect.width = __width;
		}
		if (__height != null) {
			__rect.height = __height;
		}
		return super.__getRect();
	}

	/**
	 * 获取相对于指定显示对象的边界
	 * @param parent 父显示对象，默认为null
	 * @return 计算后的边界矩形
	 */
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

	/**
	 * 获取相对于指定矩阵的边界
	 * @param parent 变换矩阵，默认为null
	 * @return 计算后的边界矩形
	 */
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

	/**
	 * 获取父类的边界计算结果
	 * @param parent 变换矩阵，默认为null
	 * @return 父类计算的边界矩形
	 */
	private function __superGetBounds(parent:Matrix = null):Rectangle {
		return super.__getBounds(parent);
	}

	/**
	 * 设置宽度
	 * @param value 要设置的宽度值
	 * @return 设置后的宽度值
	 */
	override function set_width(value:Float):Float {
		__width = value;
		__layoutDirty = true;
		return value;
	}

	/**
	 * 设置高度
	 * @param value 要设置的高度值
	 * @return 设置后的高度值
	 */
	override function set_height(value:Float):Float {
		__height = value;
		__layoutDirty = true;
		return value;
	}
}
