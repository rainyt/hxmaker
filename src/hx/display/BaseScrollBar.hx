package hx.display;

/**
 * 滚动条基类，实现了IScrollBar接口
 * 提供了滚动条的基本功能和属性
 */
class BaseScrollBar extends Box implements IScrollBar {
	/**
	 * 关联的滚动容器
	 */
	public var scroll:Scroll;

	/**
	 * 拖拽的矩形显示对象
	 * 用户可以通过拖拽此对象来控制滚动位置
	 */
	public var dragDisplay:DisplayObject;

	/**
	 * 背景显示对象
	 * 滚动条的背景元素
	 */
	public var backageDisplay:DisplayObject;

	/**
	 * 最小值的内部存储
	 */
	private var __min:Float = 0;
	/**
	 * 最大值的内部存储
	 */
	private var __max:Float = 1;
	/**
	 * 当前值的内部存储
	 */
	private var __value:Float = 0;

	/**
	 * 滚动条的最小值
	 * @return 滚动条的最小值
	 */
	public var min(get, set):Float;

	/**
	 * 获取滚动条的最小值
	 * @return 滚动条的最小值
	 */
	private function get_min():Float {
		return __min;
	}

	/**
	 * 设置滚动条的最小值
	 * @param value 要设置的最小值
	 * @return 设置后的最小值
	 */
	private function set_min(value:Float):Float {
		__min = value;
		return value;
	}

	/**
	 * 滚动条的最大值
	 * @return 滚动条的最大值
	 */
	public var max(get, set):Float;

	/**
	 * 获取滚动条的最大值
	 * @return 滚动条的最大值
	 */
	private function get_max():Float {
		return __max;
	}

	/**
	 * 设置滚动条的最大值
	 * @param value 要设置的最大值
	 * @return 设置后的最大值
	 */
	private function set_max(value:Float):Float {
		__max = value;
		return value;
	}

	/**
	 * 滚动条的当前值
	 * @return 滚动条的当前值
	 */
	public var value(get, set):Float;

	/**
	 * 获取滚动条的当前值
	 * @return 滚动条的当前值
	 */
	private function get_value():Float {
		return __value;
	}

	/**
	 * 设置滚动条的当前值
	 * @param value 要设置的当前值
	 * @return 设置后的当前值
	 */
	private function set_value(value:Float):Float {
		__value = value;
		return value;
	}

	/**
	 * 初始化滚动条
	 */
	override function onInit() {
		super.onInit();
	}

	/**
	 * 进行测量
	 * @param isScroll 是否正在滚动
	 */
	public function measure(isScroll:Bool = false):Void {}
}
