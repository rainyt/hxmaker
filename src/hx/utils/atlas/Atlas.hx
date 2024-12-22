package hx.utils.atlas;

import hx.display.BitmapData;

/**
 * 精灵图
 */
class Atlas {
	/**
	 * 原始位图
	 */
	public var bitmapData:BitmapData;

	/**
	 * 精灵图
	 */
	public var bitmapDatas:Map<String, BitmapData> = [];

	public function new(bitmapData:BitmapData) {
		this.bitmapData = bitmapData;
	}

	/**
	 * 解析精灵图
	 */
	public function parser():Void {}
}
