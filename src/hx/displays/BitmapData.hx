package hx.displays;

/**
 * 位图显示对象
 */
class BitmapData {
	/**
	 * 通过data返回的位图数据
	 * @param data 
	 */
	public static function formData(data:IBitmapData) {
		var bitmapData = new BitmapData();
		bitmapData.__data = data;
		return bitmapData;
	}

	/**
	 * 位图数据
	 */
	@:noCompletion private var __data:IBitmapData;

	public function new() {}
}
