package hx.core;

import openfl.display.Bitmap;

/**
 * 批处理位图渲染支持
 */
class BatchBitmapState {
	/**
	 * 待渲染的位图数据列表
	 */
	public var bitmaps:Array<Bitmap> = [];

	public function new() {}

	/**
	 * 重置
	 */
	public function reset():Void {
		bitmaps = [];
	}

	/**
	 * 如果使用的资产是相同的，则追加成功
	 * @param bitmap 
	 * @return Bool
	 */
	public function push(bitmap:Bitmap):Bool {
		if (bitmaps.length == 0 || bitmaps[bitmaps.length - 1].bitmapData == bitmap.bitmapData) {
			bitmaps.push(bitmap);
			return true;
		}
		return false;
	}
}
