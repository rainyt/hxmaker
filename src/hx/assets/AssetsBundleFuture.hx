package hx.assets;

import haxe.io.Bytes;
import hx.events.FutureErrorEvent;

using haxe.io.Path;

/**
 * 资源压缩包加载器
 */
class AssetsBundleFuture extends Future<AssetsBundle, String> {
	/** 可选资源包失败后允许继续按单文件加载；默认保留原来的失败行为。 */
	public var optional:Bool = false;

	/**
	 * 通知加载失败，并保留资源路径
	 */
	private function fail(message:String):Void {
		if (optional) {
			trace("可选资源包不可用，继续加载单文件：" + this.path + "，" + message);
			this.completeValue(new AssetsBundle());
			return;
		}
		var event:FutureErrorEvent = FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, message, this.path);
		event.path = this.path;
		this.errorValue(event);
	}

	/**
	 * 判断压缩包是否存在
	 */
	public function existBundle(filePath:String):Bool {
		// 同步接口
		#if (wechat_zygame_dom > '5.6.4')
		try {
			Wx.getFileSystemManager().accessSync(filePath);
			return true;
		} catch (e) {}
		#end
		return false;
	}

	/**
	 * 解压压缩包
	 */
	public function unzip(filePath:String, targetPath:String):Void {
		#if (wechat_zygame_dom > '5.6.4')
		Wx.getFileSystemManager().unzip({
			zipFilePath: filePath,
			targetPath: targetPath,
			success: function(res:Dynamic):Void {
				trace("解压成功", res);
				Wx.getFileSystemManager().unlink({
					filePath: filePath,
					fail: function(res:Dynamic):Void {
						trace("删除文件失败", res, filePath);
					},
					success: function(res:Dynamic):Void {
						// 将文件缓存起来，避免下次重复下载
						var cachePath:String = StringTools.replace(filePath, ".zip", ".cache");
						Wx.getFileSystemManager().writeFile({
							filePath: cachePath,
							data: "ok",
							success: function(res:Dynamic):Void {
								trace("缓存文件成功", res, cachePath);
							},
							fail: function(res:Dynamic):Void {
								trace("缓存文件失败", res, cachePath);
							}
						});
					}
				});
				var assetsBundle:AssetsBundle = new AssetsBundle();
				this.completeValue(assetsBundle);
			},
			fail: function(data:Dynamic):Void {
				trace("解压失败", data);
				Wx.getFileSystemManager().unlink({filePath: filePath});
				this.fail("资源包解压失败：" + Std.string(data));
			}
		});
		#else
		this.fail("当前平台不支持通过文件路径解压资源包：" + filePath);
		#end
	}

	override function post():Void {
		super.post();
		#if (wechat_zygame_dom > '5.6.4')
		var id:String = haxe.crypto.Md5.encode(path);
		// 微信小游戏版本改进，将压缩包储存到本地，进行解压，如果压缩包已经存在，则不重复加载。使用Wx.downloadFile下载压缩包
		var filePath:String = Path.join([Wx.env.USER_DATA_PATH, id + ".zip"]);
		var cachePath:String = Path.join([Wx.env.USER_DATA_PATH, id + ".cache"]);
		var target:String = Path.join([Wx.env.USER_DATA_PATH]);
		trace("download bundle:", filePath, ">", target);
		if (!existBundle(cachePath)) {
			if (!existBundle(filePath))
				Wx.downloadFile({
					url: hx.assets.Assets.getDefaultNativePath(this.path),
					filePath: filePath,
					timeout: optional ? 12000 : 60000,
					enableHttp2: true,
					success: function(res:Dynamic):Void {
						if (res.statusCode == 200)
							unzip(filePath, target);
						else {
							Wx.getFileSystemManager().unlink({filePath: filePath});
							this.fail("资源包下载 HTTP 状态异常：" + Std.string(res.statusCode));
						}
					},
					fail: function(data:Dynamic):Void {
						// 临时文件无法下载，意味着资源无法被下载
						trace("wx.downloadFile fail:", path, data);
						Wx.getFileSystemManager().unlink({filePath: filePath});
						this.fail("资源包下载失败：" + Std.string(data));
					}
				});
			else {
				trace("skin bundle exist:", filePath, ">", target);
				unzip(filePath, target);
			}
		} else {
			var assetsBundle:AssetsBundle = new AssetsBundle();
			this.completeValue(assetsBundle);
		}
		#else
		new BytesFuture(this.path, true).onComplete(function(bytes:AssetObject<Bytes>):Void {
			this.addAssetObject(bytes);
			var assetsBundle:AssetsBundle;
			try {
				assetsBundle = new AssetsBundle(bytes.data);
			} catch (error:Dynamic) {
				this.fail("资源包解析失败：" + Std.string(error));
				return;
			}
			this.completeValue(assetsBundle);
		}).onError((error:FutureErrorEvent) -> this.fail(error.toString()));
		#end
	}
}
