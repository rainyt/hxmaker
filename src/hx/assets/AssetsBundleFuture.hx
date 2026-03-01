package hx.assets;

import haxe.io.Bytes;

using haxe.io.Path;

/**
 * 资源压缩包加载器
 */
class AssetsBundleFuture extends Future<AssetsBundle, String> {
	/**
	 * 判断压缩包是否存在
	 */
	public function existBundle(filePath:String):Bool {
		// 同步接口
		#if wechat_zygame_dom
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
		#if wechat_zygame_dom
		Wx.getFileSystemManager().unzip({
			zipFilePath: filePath,
			targetPath: targetPath,
			success: function(res:Dynamic):Void {
				trace("解压成功", res);
				var assetsBundle = new AssetsBundle();
				this.completeValue(assetsBundle);
			},
			fail: function(data:Dynamic) {
				trace("解压失败", data);
				var assetsBundle = new AssetsBundle();
				this.completeValue(assetsBundle);
			}
		});
		#else
		trace("unzip not support");
		#end
	}

	override function post() {
		super.post();
		#if wechat_zygame_dom
		var id = haxe.crypto.Md5.encode(path);
		// 微信小游戏版本改进，将压缩包储存到本地，进行解压，如果压缩包已经存在，则不重复加载。使用Wx.downloadFile下载压缩包
		var filePath = Path.join([Wx.env.USER_DATA_PATH, id + ".zip"]);
		var target = Path.join([Wx.env.USER_DATA_PATH]);
		trace("download bundle:", filePath, ">", target);
		if (!existBundle(filePath))
			Wx.downloadFile({
				url: hx.assets.Assets.getDefaultNativePath(this.path),
				filePath: filePath,
				timeout: 60000,
				enableHttp2: true,
				success: function(res:Dynamic):Void {
					unzip(filePath, target);
				},
				fail: function(data:Dynamic) {
					// 临时文件无法下载，意味着资源无法被下载
					trace("wx.donwloadFile fail:", path, data);
				}
			});
		else {
			trace("skin bundle exist:", filePath, ">", target);
			unzip(filePath, target);
		}
		#else
		new BytesFuture(this.path, true).onComplete(function(bytes:Bytes) {
			// 加载完成
			var assetsBundle = new AssetsBundle(bytes);
			this.completeValue(assetsBundle);
		}).onError(this.errorValue);
		#end
	}
}
