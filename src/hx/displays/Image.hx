package hx.displays;

/**
 * 使用位图进行渲染的图像
 */
@:keep
class Image extends DisplayObject implements IDataProider<BitmapData> {
	@:noCompletion private var __bitmapData:BitmapData;
	@:noCompletion private var __smoothing:Bool = true;

	/**
	 * 设置、获取位图数据
	 */
	public var data(get, set):BitmapData;

	private function set_data(value:BitmapData):BitmapData {
		__bitmapData = value;
		return value;
	}

	private function get_data():BitmapData {
		return __bitmapData;
	}

	/**
	 * 平滑处理，默认为`false`
	 */
	public var smoothing(get, set):Bool;

	private function set_smoothing(value:Bool):Bool {
		__smoothing = value;
		return value;
	}

	private function get_smoothing():Bool {
		return __smoothing;
	}

	/**
	 * 构造一个位图对象
	 * @param data 
	 */
	public function new(?data:BitmapData) {
		super();
		if (data != null) {
			this.data = data;
		}
	}
}
