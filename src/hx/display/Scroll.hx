package hx.display;

import hx.gemo.Rectangle;

/**
 * 滚动遮罩支持的容器
 */
class Scroll extends Box {
	override function onInit() {
		super.onInit();
		this.makeRect = new Rectangle(0, 0, 100, 100);
		this.width = 100;
		this.height = 100;
	}

	override function set_width(value:Float):Float {
		this.makeRect.width = value;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		this.makeRect.height = value;
		return super.set_height(value);
	}
}
