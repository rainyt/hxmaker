package hx.display;

import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;

/**
 * 滚动组件
 */
class BaseScrollBar extends Box implements IScrollBar {
	public var scroll:Scroll;

	/**
	 * 拖拽的矩形
	 */
	public var dragDisplay:DisplayObject;

	/**
	 * 背景显示对象
	 */
	public var backageDisplay:DisplayObject;

	private var __min:Float = 0;
	private var __max:Float = 1;
	private var __value:Float = 0;

	public var min(get, set):Float;

	private function get_min():Float {
		return __min;
	}

	private function set_min(value:Float):Float {
		__min = value;
		return value;
	}

	public var max(get, set):Float;

	private function get_max():Float {
		return __max;
	}

	private function set_max(value:Float):Float {
		__max = value;
		return value;
	}

	public var value(get, set):Float;

	private function get_value():Float {
		return __value;
	}

	private function set_value(value:Float):Float {
		__value = value;
		return value;
	}

	override function onInit() {
		super.onInit();
	}

	/**
	 * 进行测量
	 */
	public function measure(isScroll:Bool = false):Void {}
}
