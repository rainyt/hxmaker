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

	private var assetReferences:Int = 0;
	public var cacheEntryId(default, null):Int = 0;

	/**
	 * 子资源处理
	 */
	public var childAssetObjects:Array<AssetObject<Dynamic>> = [];

	public function new(key:String, data:Dynamic) {
		this.data = data;
		this.nativePath = key;
		#if openfl
		cacheEntryId = hx.net.RequestQueue.getEntryId(key);
		#end
	}

	/**
	 * 保留资源（增加引用计数）
	 * 当资源被多个 Assets 共享时调用，
	 * 例如 pushAssets 将资源从一个 Assets 合并到另一个时
	 */
	public function retain():Void {
		assetReferences++;
		for (object in childAssetObjects) {
			object.retain();
		}
		#if openfl
		if (cacheEntryId > 0) hx.net.RequestQueue.retain(this.nativePath, cacheEntryId);
		#end
	}

	/**
	 * 释放资源
	 */
	public function release():Void {
		if (assetReferences <= 0) return;
		assetReferences--;
		if (assetReferences == 0 && data is Atlas) cast(data, Atlas).dispose();
		for (object in childAssetObjects) {
			object.release();
		}
		#if openfl
		if (cacheEntryId > 0) hx.net.RequestQueue.release(this.nativePath, cacheEntryId);
		#end
	}
}
