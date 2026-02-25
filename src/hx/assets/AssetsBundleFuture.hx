package hx.assets;

import haxe.io.Bytes;

/**
 * 资源压缩包加载器
 */
class AssetsBundleFuture extends Future<AssetsBundle, String> {
	override function post() {
		super.post();
		new BytesFuture(this.path, true).onComplete(function(bytes:Bytes) {
			// 加载完成
			var assetsBundle = new AssetsBundle(bytes);
			this.completeValue(assetsBundle);
		}).onError(this.errorValue);
	}
}
