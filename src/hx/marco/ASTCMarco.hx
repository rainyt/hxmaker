package hx.marco;

#if macro
import haxe.Json;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.macro.Context;
import haxe.zip.Compress;
import hx.tools.astc.ASTCBuilder;
import hx.tools.astc.ASTCBuildOptions;
import hx.assets.astc.ASTCManifestData;
import sys.FileSystem;
import sys.io.File;
#end

/** ASTC 编译入口；按目录调用多次，统一合并并压缩清单。 */
class ASTCMarco {
	#if macro
	private static var pending:Map<String, ASTCManifestData> = [];
	private static var scheduled:Bool = false;

	/** 增量生成同路径 ASTC 并内嵌清单；options.zlib 可开启纹理外层压缩，第二个参数对应 assets 的 rename。 */
	public static function build(source:String, prefix:String, ?options:ASTCBuildOptions):Void {
		if (Context.defined("display"))
			return;
		var previousDirectory:String = Sys.getCwd();
		var projectRoot:Null<String> = Context.definedValue("hxmaker_astc_project_root");
		try {
			if (projectRoot != null)
				Sys.setCwd(projectRoot);
			var result:hx.tools.astc.ASTCBuilder.ASTCBuildResult = ASTCBuilder.build(source, prefix, options);
			pending.set(haxe.io.Path.normalize(FileSystem.absolutePath(source)) + "\n" + result.manifest.prefix, result.manifest);
			if (!scheduled) {
				scheduled = true;
				Context.onAfterInitMacros(finishManifest);
			}
			var assetFile:String = Context.definedValue("hxmaker_astc_assets");
			if (assetFile != null) {
				var xml:Xml = Xml.parse(File.getContent(assetFile));
				for (existing in xml.firstElement().elementsNamed("assets")) {
					if (existing.get("rename") == result.manifest.prefix && existing.get("path") != result.output)
						throw "多个 ASTC 目录使用了相同资源前缀：" + prefix;
				}
				var asset:Xml = Xml.createElement("assets");
				asset.set("path", result.output);
				asset.set("rename", result.manifest.prefix);
				asset.set("include", "*.astc");
				asset.set("type", "binary");
				asset.set("embed", "false");
				if (FileSystem.exists(result.output))
					xml.firstElement().addChild(asset);
				ASTCBuilder.writeIfChanged(assetFile, xml.toString());
			}
			Sys.setCwd(previousDirectory);
		} catch (error:Dynamic) {
			Sys.setCwd(previousDirectory);
			pending = [];
			scheduled = false;
			Context.error("ASTC 构建失败：" + Std.string(error), Context.currentPos());
		}
	}

	/** 初始化宏全部执行后合并一次，先清空临时状态以兼容编译服务的下一轮编译。 */
	private static function finishManifest():Void {
		var current:Map<String, ASTCManifestData> = pending;
		pending = [];
		scheduled = false;
		var files:Array<String> = [];
		var revisions:Array<String> = [];
		var seen:Map<String, Bool> = [];
		for (manifest in current) {
			revisions.push(manifest.prefix + ":" + manifest.revision);
			for (relative in manifest.files) {
				var key:String = manifest.prefix == "" ? relative : manifest.prefix + "/" + relative;
				if (seen.exists(key))
					Context.error("多个 ASTC 目录包含相同资源路径：" + key, Context.currentPos());
				seen.set(key, true);
				files.push(key);
			}
		}
		files.sort(Reflect.compare);
		revisions.sort(Reflect.compare);
		var content:Bytes = Bytes.ofString(Json.stringify({schemaVersion: 1, revision: Sha256.encode(revisions.join("\n")), files: files}));
		// 初始化宏没有调用方模块，资源名不能以 $ 开头，否则 Haxe 4.3 会触发断言。
		Context.addResource("hxmaker.astc.manifest", Compress.run(content, 9));
	}
	#end
}
