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

	/**
	 * 根据名字获得位图数组，并会对名字进行一个排序处理
	 * @param name 
	 * @return Array<BitmapData>
	 */
	public function getBitmapDatasByName(name:String):Array<BitmapData> {
		var array = [];
		for (key => value in bitmapDatas) {
			if (key.indexOf(name) != -1) {
				array.push(value);
			}
		}
		return array;
	}
}
