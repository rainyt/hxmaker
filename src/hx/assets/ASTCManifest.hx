package hx.assets;

import haxe.Json;
import haxe.Resource;
import haxe.io.Bytes;
import haxe.zip.Uncompress;

/** 读取宏合并后内嵌的压缩清单，不访问网络或依赖平台文件系统。 */
class ASTCManifest {
	public static inline var RESOURCE_NAME:String = "$hxmaker.astc.manifest";
	public static var enabled:Bool = true;
	private static var loaded:Bool = false;
	private static var configured:Bool = false;
	private static var files:Map<String, Bool> = [];
	private static var version:String = "";

	/** 是否启用了宏清单，包括清单有效但没有任何成功编码图片的情况。 */
	public static function isConfigured():Bool {
		load();
		return configured;
	}

	/** 返回清单内容版本，用于隔离下载缓存。 */
	public static function getVersion():String {
		load();
		return version;
	}

	/** 只为清单内的原图片返回 ASTC 路径；不改写外部域名和查询参数。 */
	public static function resolve(path:String):Null<String> {
		load();
		if (!enabled || path == null)
			return null;
		var suffixIndex:Int = path.length;
		for (separator in ["?", "#"]) {
			var index:Int = path.indexOf(separator);
			if (index >= 0 && index < suffixIndex)
				suffixIndex = index;
		}
		var key:String = path.substr(0, suffixIndex);
		if (key.indexOf("://") >= 0) {
			var base:String = Assets.defaultNativePath;
			if (base == null)
				return null;
			base = StringTools.endsWith(base, "/") ? base : base + "/";
			if (!StringTools.startsWith(key, base))
				return null;
			key = key.substr(base.length);
		}
		key = StringTools.replace(key, "\\", "/");
		while (StringTools.startsWith(key, "./"))
			key = key.substr(2);
		if (!files.exists(key) || !StringTools.endsWith(key, ".png"))
			return null;
		return path.substr(0, suffixIndex - 4) + ".astc" + path.substr(suffixIndex);
	}

	/** 延迟解压一次；任意清单异常时停用替换，继续使用原资源。 */
	private static function load():Void {
		if (loaded)
			return;
		loaded = true;
		var compressed:Bytes = Resource.getBytes(RESOURCE_NAME);
		if (compressed == null)
			return;
		configured = true;
		try {
			var manifest:{schemaVersion:Int, revision:String, files:Array<String>} = Json.parse(Uncompress.run(compressed).toString());
			if (manifest.schemaVersion != 1 || manifest.files == null || manifest.revision == null)
				throw "不支持的 ASTC 清单格式";
			for (path in manifest.files) {
				if (path == null || path.split("/").indexOf("..") >= 0 || path.indexOf(":") >= 0 || StringTools.startsWith(path, "/"))
					throw "ASTC 清单包含无效路径";
				files.set(path, true);
			}
			version = manifest.revision;
		} catch (error:Dynamic) {
			files = [];
			version = "invalid";
			trace("ASTC 清单不可用，使用原资源：" + Std.string(error));
		}
	}
}

