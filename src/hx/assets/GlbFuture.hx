package hx.assets;

import haxe.crypto.Sha256;
import hx.events.FutureErrorEvent;

/** 二进制与内嵌图片都完成后才完成 GLB；所有子资源交给 Assets 引用计数管理。 */
class GlbFuture extends Future<GlbAsset, String> {
	private var pending:Bool = false;
	private var children:Array<AssetObject<Dynamic>> = [];
	override public function post():Void {
		if (pending || isComplete) return;
		pending = true; isError = false; error = null;
		var bytes = new BytesFuture(getLoadData(), false);
		bytes.onComplete(object -> {
			var asset:GlbAsset;
			children.push(object);
			try { asset = GlbAsset.fromBytes(object.data); }
			catch (error:Dynamic) { fail("GLB 解析失败：" + Std.string(error)); return; }
			progressValue(0.7);
			decodeNext(asset, 0);
		});
		bytes.onError(error -> { fail(error.error, error.errorCode); });
		bytes.onProgress(value -> progressValue(value*0.7)); bytes.post();
	}
	private function decodeNext(asset:GlbAsset, index:Int):Void {
		if (index == asset.imageCount) {
			for (texture in asset.data.textures) if (texture.wrapU != 33071 || texture.wrapV != 33071) {
				var bitmap = asset.images[texture.source], width = Std.int(bitmap.width), height = Std.int(bitmap.height);
				if ((width & (width-1)) != 0 || (height & (height-1)) != 0) {
					fail("GLB 重复或镜像采样当前要求二次幂图片，非二次幂图片请使用 CLAMP"); return;
				}
			}
			for (object in children) addAssetObject(object);
			children = []; pending = false; progressValue(1); completeValue(asset); return;
		}
		var image = asset.data.images[index];
		// 内容摘要避免同一路径热更新沿用旧图，并让重复图片共享解码与 GPU 资源。
		var key = "hxmaker:embedded-image:sha256:" + Sha256.make(image.bytes).toHex();
		var future = new BitmapDataBytesFuture({bytes:image.bytes, path:key}, false);
		future.onComplete(object -> {
			children.push(object); asset.images[index] = object.data;
			progressValue(0.7 + 0.3*(index + 1)/asset.imageCount);
			// 缓存命中可同步回调，下一张延迟调度，避免大量图片形成递归调用链。
			haxe.Timer.delay(() -> decodeNext(asset, index + 1), 0);
		});
		future.onError(error -> fail("GLB 图片解码失败（" + image.name + "）：" + error.error, error.errorCode));
		future.post();
	}
	private function fail(message:String, code:Int = -1):Void {
		for (object in children) object.release();
		children = []; pending = false;
		var event = FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, code, message);
		event.path = path; errorValue(event);
	}
}
