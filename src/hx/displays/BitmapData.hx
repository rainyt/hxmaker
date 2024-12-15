package hx.displays;

import hx.gemo.Rectangle;

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
		bitmapData.data = data;
		return bitmapData;
	}

	/**
	 * 位图数据
	 */
	public var data:IBitmapData;

	/**
	 * 位图切割区域
	 */
	public var rect:Rectangle;

	/**
	 * 位图的实际区域
	 */
	public var frameRect:Rectangle;

	public function new() {}

	/**
	 * 切割位图
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 * @return BitmapData
	 */
	public function sub(x:Float, y:Float, width:Float, height:Float):BitmapData {
		var bitmapData = BitmapData.formData(this.data);
		bitmapData.rect = new Rectangle(x, y, width, height);
		return bitmapData;
	}
}
