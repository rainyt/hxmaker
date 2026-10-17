package hx.assets;

import haxe.io.Bytes;
import hx.events.FutureErrorEvent;
import hx.material.TextureWrap3D;

/** 模型 Future 的共用实现；结构构建和全部图片解码完成后才交付资产。 */
@:noCompletion
class ModelAssetFuture<T:ModelAsset> extends Future<T, String> {
	private var pending:Bool = false;
	private var children:Array<AssetObject<Dynamic>> = [];
	private var importer:Bytes->T;

	public function new(path:String, autoPost:Bool, importer:Bytes->T) {
		super(path, autoPost);
		this.importer = importer;
	}

	override public function post():Void {
		if (pending || isComplete) return;
		pending = true;
		isError = false;
		error = null;
		var bytes = new BytesFuture(getLoadData(), false);
		bytes.onComplete(object -> {
			var asset:T;
			children.push(object);
			try {
				asset = importer(object.data);
			} catch (error:Dynamic) {
				fail("模型导入失败：" + Std.string(error));
				return;
			}
			progressValue(0.7);
			decodeNext(asset, 0);
		});
		bytes.onError(error -> fail(error.error, error.errorCode));
		bytes.onProgress(value -> progressValue(value * 0.7));
		bytes.post();
	}

	private function decodeNext(asset:T, index:Int):Void {
		var model:ModelAsset = asset;
		if (index == asset.imageCount) {
			for (texture in model.data.textures)
				if (texture.wrapU != TextureWrap3D.CLAMP || texture.wrapV != TextureWrap3D.CLAMP) {
					var bitmap = model.images[texture.source], width = Std.int(bitmap.width), height = Std.int(bitmap.height);
					if ((width & (width - 1)) != 0 || (height & (height - 1)) != 0) {
						fail("模型重复或镜像采样当前要求二次幂图片，非二次幂图片请使用 CLAMP");
						return;
					}
				}
			for (object in children) addAssetObject(object);
			children = [];
			pending = false;
			progressValue(1);
			completeValue(asset);
			return;
		}
		var image = model.data.images[index];
		var key = "hxmaker:embedded-image:sha256:" + image.contentHash;
		var future = new BitmapDataBytesFuture({bytes: image.bytes, path: key}, false);
		future.onComplete(object -> {
			children.push(object);
			model.images[index] = object.data;
			progressValue(0.7 + 0.3 * (index + 1) / asset.imageCount);
			// 缓存命中可同步回调，延迟继续，避免图片数量较多时形成递归调用链。
			haxe.Timer.delay(() -> decodeNext(asset, index + 1), 0);
		});
		future.onError(error -> fail("模型图片解码失败（" + image.name + "）：" + error.error, error.errorCode));
		future.post();
	}

	private function fail(message:String, code:Int = -1):Void {
		for (object in children) object.release();
		children = [];
		pending = false;
		var event = FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, code, message);
		event.path = path;
		errorValue(event);
	}
}
