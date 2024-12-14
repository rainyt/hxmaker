package hx.displays;

/**
 * 使用位图进行渲染的图像
 */
@:keep
class Image extends DisplayObject implements IDataProider<BitmapData> {
	@:noCompletion private var __bitmapData:BitmapData;

	/**
	 * 设置、获取位图数据
	 */
	public var data(get, set):BitmapData;

	public function set_data(value:BitmapData):BitmapData {
		__bitmapData = value;
		return value;
	}

	public function get_data():BitmapData {
		return __bitmapData;
	}
}
