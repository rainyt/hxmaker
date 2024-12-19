package hx.displays;

import hx.providers.IRootDataProvider;

/**
 * 矩形渲染显示对象
 */
class Quad extends DisplayObject implements IDataProider<UInt> implements IRootDataProvider<Dynamic> {
	public var root(get, set):Dynamic;

	@:noCompletion private function get_root():Dynamic {
		return __root;
	}

	@:noCompletion private function set_root(value:Dynamic):Dynamic {
		this.__root = value;
		return __root;
	}

	/**
	 * 设置颜色值
	 */
	public var data(get, set):UInt;

	private var _data:UInt;

	public function get_data():UInt {
		return _data;
	}

	public function set_data(value:UInt):UInt {
		_data = value;
		return value;
	}

	/**
	 * 构造一个色块渲染对象
	 * @param width 宽度
	 * @param height 高度
	 * @param color 颜色
	 */
	public function new(width:Int = 0, height:Int = 0, color:UInt = 0x0) {
		super();
		this.width = width;
		this.height = height;
		this.data = color;
	}
}
