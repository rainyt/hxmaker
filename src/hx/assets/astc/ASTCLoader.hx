package hx.assets.astc;

import haxe.Timer;
import haxe.io.Bytes;
import hx.assets.BytesFuture;
import hx.display.BitmapData;

using StringTools;

/**
 * 运行时 ASTC 分发：资源包命中的位图由调用方优先处理，这里只接管清单命中的纹理。
 * 清单一旦命中即视为该资源只提供 ASTC，加载失败直接回报错误，不回退原图。
 */
class ASTCLoader {
	/** 由渲染后端注入的解码器，核心只通过接口调用。 */
	public static var decoder(default, null):IASTCDecoder;

	/** 单张纹理等待字节的超时时间。 */
	public static var timeoutMilliseconds:Int = 60000;

	/** 解压后允许的最大 ASTC 字节数。 */
	public static var maxBytes:Int = 67108864;

	/** 绑定后端的 ASTC 解码器；可重复调用以便替换实现或测试。 */
	public static function registerDecoder(value:IASTCDecoder):Void {
		decoder = value;
	}

	/**
	 * 尝试接管一次图片请求。
	 * @param url 原图请求路径
	 * @param callback 成功时给出位图，失败时给出错误信息
	 * @return false 表示该路径与 ASTC 无关，调用方继续原图流程；true 表示已接管，成功或失败只回调一次
	 */
	public static function load(url:String, callback:BitmapData->Null<String>->Void):Bool {
		var current:IASTCDecoder = decoder;
		if (current == null || !current.isSupported())
			return false;
		var path:Null<String> = resolvePath(url);
		if (path == null)
			return false;
		var settled:Bool = false;
		var timer:Timer = null;
		function finish(bitmap:BitmapData, error:Null<String>):Void {
			if (settled)
				return;
			settled = true;
			if (timer != null)
				timer.stop();
			callback(bitmap, error);
		}
		function deferFinish(bitmap:BitmapData, error:Null<String>):Void {
			// 资源包里的字节是同步返回的，统一推迟到下一轮，避免在请求计数更新前结算。
			Timer.delay(function() finish(bitmap, error), 0);
		}
		timer = Timer.delay(function() deferFinish(null, "ASTC 加载超时：" + path), timeoutMilliseconds);
		var future:BytesFuture = new BytesFuture(path, false);
		future.onComplete(function(data):Void {
			var bytes:Bytes = data.data;
			// 压缩字节只用于本次上传，显式归还缓存引用，避免长期驻留。
			data.release();
			var bitmap:BitmapData = null;
			var error:Null<String> = null;
			try {
				bitmap = current.fromBytes(ASTCFormat.decode(bytes, maxBytes, current.inflate));
			} catch (failure:Dynamic) {
				error = "ASTC 解码失败：" + Std.string(failure);
			}
			if (bitmap == null && error == null)
				error = "ASTC 解码结果无效：" + path;
			deferFinish(bitmap, error);
		}).onError(function(failure):Void {
			deferFinish(null, "ASTC 加载失败：" + Std.string(failure == null ? path : failure.error));
		});
		try {
			future.post();
		} catch (failure:Dynamic) {
			deferFinish(null, "ASTC 请求异常：" + Std.string(failure));
		}
		return true;
	}

	/** 只有显式 `.astc` 或清单命中的路径才走 ASTC。 */
	private static function resolvePath(url:String):Null<String> {
		var clean:String = url;
		for (separator in ["?", "#"]) {
			var index:Int = clean.indexOf(separator);
			if (index >= 0)
				clean = clean.substr(0, index);
		}
		if (clean.endsWith(".astc"))
			return url;
		if (!ASTCManifest.enabled)
			return null;
		return ASTCManifest.resolve(url);
	}
}
