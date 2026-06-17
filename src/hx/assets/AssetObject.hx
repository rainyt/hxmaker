package hx.assets;

/**
 * 每次通过Future加载的时候，
 */
class AssetObject<T> {
	/**
	 * 资源数据
	 */
	public var data:T;

	/**
	 * 资源的原始路径，可能是网络路径，也可能是本地路径，或者其他路径，取决于Future的实现
	 */
	public var nativePath:String = "";

	/**
	 * 子资源处理
	 */
	public var childAssetObjects:Array<AssetObject<Dynamic>> = [];

	public function new(key:String, data:Dynamic) {
		this.data = data;
		this.nativePath = key;
	}

	/**
	 * 保留资源（增加引用计数）
	 * 当资源被多个 Assets 共享时调用，
	 * 例如 pushAssets 将资源从一个 Assets 合并到另一个时
	 */
	public function retain():Void {
		#if openfl
		hx.net.RequestQueue.retain(this.nativePath);
		#end
	}

	/**
	 * 释放资源
	 */
	public function release():Void {
		for (object in childAssetObjects) {
			object.release();
		}
		#if openfl
		hx.net.RequestQueue.release(this.nativePath);
		#end
	}
}
