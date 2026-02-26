package hx.assets;

import haxe.crypto.Md5;
import js.lib.ArrayBuffer;
import haxe.crypto.Base64;
import hx.utils.Timer;
import hx.events.FutureErrorEvent;
import hx.core.OpenFlBitmapData;
import hx.display.BitmapData;
import haxe.io.Bytes;

using haxe.io.Path;

/**
 * 资源压缩包
 */
class AssetsBundle {
	/**
	 * 压缩包对象
	 */
	public var zip:Zip;

	public function new(?bytes:Bytes) {
		if (bytes == null)
			return;
		zip = new Zip(bytes);
		zip.unzip();
	}

	/**
	 * 获取资源
	 */
	public function has(name:String):Bool {
		if (zip == null)
			return false;
		var id = name.withoutDirectory();
		return zip.entrys.exists(id);
	}

	/**
	 * 获得二进制数据
	 */
	public function get(name:String):Bytes {
		if (zip == null)
			return null;
		var id = name.withoutDirectory();
		var entry = zip.entrys.get(id);
		zip.decompress(entry);
		return entry.data;
	}

	/**
	 * 获取图片类型
	 */
	private function getImageType(bytes:Bytes):String {
		#if lime
		if (@:privateAccess lime.graphics.Image.__isPNG(bytes)) {
			return "image/png";
		} else if (@:privateAccess lime.graphics.Image.__isJPG(bytes)) {
			return "image/jpeg";
		} else if (@:privateAccess lime.graphics.Image.__isGIF(bytes)) {
			return "image/gif";
		} else if (@:privateAccess lime.graphics.Image.__isWebP(bytes)) {
			return "image/webp";
		}
		#end
		return throw "AssetsBundle.getImageType() not support";
	}

	/**
	 * 加载位图资源
	 */
	public function loadBitmapData(name:String):Future<BitmapData, Dynamic> {
		if (zip == null)
			return null;
		var future = new Future<BitmapData, Dynamic>(null);
		var bytes = get(name);
		#if wechat_zygame_dom
		// 微信小游戏使用unzip包支持
		return null;
		#elseif lime
		lime.graphics.Image.loadFromBase64(Base64.encode(bytes), getImageType(bytes)).onComplete((img) -> {
			if (img == null) {
				Timer.getInstance().nextFrame(function() {
					future.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load bitmap data failed"));
				});
			} else {
				future.completeValue(BitmapData.formData(new OpenFlBitmapData(openfl.display.BitmapData.fromImage(img))));
			}
		}).onError(function(error:String) {
			future.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, error));
		});
		#else
		throw "AssetsBundle.loadBitmapData() not support";
		#end
		return future;
	}
}
