package hx.utils;

import hx.displays.BitmapData;

/**
 * 资源管理器
 */
class Assets {
	public function new() {}

	/**
	 * 加载位图资源
	 * @param path 
	 * @return Future<BitmapData>
	 */
	public function loadBitmapData(path:String):Future<BitmapData> {
		return new hx.core.BitmapDataFuture(path);
	}
}
