package hx.tools.astc;

#if (sys || macro)
import haxe.DynamicAccess;
import haxe.Json;
import haxe.crypto.Sha256;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Compress;
import hx.assets.ASTCFormat;
import hx.assets.ASTCManifestData;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

/** 编译宏和构建准备阶段共用的增量编码器，不依赖 OpenFL 运行时。 */
class ASTCBuilder {
	/** 扫描目录并生成有效图片清单；失败图片不再复用旧 ASTC。 */
	public static function build(source:String, prefix:String, ?options:ASTCBuildOptions):ASTCBuildResult {
		if (options == null)
			options = {};
		source = Path.normalize(FileSystem.absolutePath(source));
		prefix = normalizePrefix(prefix);
		var output:String = Path.normalize(FileSystem.absolutePath(options.output ?? source + "_ASTC"));
		if (output == source || StringTools.startsWith(output + "/", source + "/"))
			throw "ASTC 输出目录必须独立于源目录：" + output;
		FileSystem.createDirectory(output);
		if (FileSystem.exists(source)) {
			var realSource:String = Path.normalize(FileSystem.fullPath(source));
			var realOutput:String = Path.normalize(FileSystem.fullPath(output));
			if (realSource == realOutput || StringTools.startsWith(realOutput + "/", realSource + "/"))
				throw "ASTC 输出目录不能通过符号链接指向源目录";
		}
		var cacheDir:String = Path.join([Sys.getCwd(), ".hxmaker", "astc"]);
		FileSystem.createDirectory(cacheDir);
		var cacheId:String = Sha256.encode(source + "\n" + prefix + "\n" + output);
		var cachePath:String = Path.join([cacheDir, cacheId + ".cache.json"]);
		var previous:DynamicAccess<ASTCCacheEntry> = readCache(cachePath);
		var next:DynamicAccess<ASTCCacheEntry> = {};
		var files:Array<String> = [];
		var revisions:Array<String> = [];
		var converted:Int = 0;
		var reused:Int = 0;
		var failed:Int = 0;
		var inputs:Array<String> = [];
		if (FileSystem.exists(source) && FileSystem.isDirectory(source))
			scan(source, "", inputs, Path.normalize(FileSystem.fullPath(source)));
		else if (options.strict == true)
			throw "ASTC 源目录不存在：" + source;
		else
			Sys.println("[ASTC] 源目录不存在，清单使用空目录：" + source);
		inputs.sort(Reflect.compare);
		// 全部命中缓存时，不查找编码器，也不读取编码器状态。
		var encoder:Null<String> = null;
		var settings:Null<String> = null;
		var block:String = options.block ?? "6x6";
		var quality:String = options.quality ?? "-exhaustive";
		var premultiply:Bool = options.alphaPremultiply != false;
		var zlib:Bool = options.zlib == true;
		var zlibLevel:Int = zlib ? (options.zlibLevel ?? 9) : 0;
		if (zlibLevel < 0 || zlibLevel > 9)
			throw "zlib 压缩等级必须在 0～9 之间";
		if (["4x4", "5x4", "5x5", "6x5", "6x6", "8x5", "8x6", "8x8", "10x5", "10x6", "10x8", "10x10", "12x10", "12x12"].indexOf(block) < 0)
			throw "不支持的 ASTC 压缩块：" + block;
		if (["-fastest", "-fast", "-medium", "-thorough", "-verythorough", "-exhaustive"].indexOf(quality) < 0)
			throw "不支持的 ASTC 编码质量：" + quality;
		for (relative in inputs) {
			var input:String = Path.join([source, relative]);
			var target:String = Path.join([output, relative.substr(0, relative.length - 4) + ".astc"]);
			var temporary:Null<String> = null;
			try {
				var stat:sys.FileStat = FileSystem.stat(input);
				var cached:ASTCCacheEntry = previous.get(relative);
				var sameMtime:Bool = cached != null && cached.mtime == stat.mtime.getTime();
				// 默认仅按源图修改时间复用，不读取图片内容、输出文件头或解压 zlib。
				if (options.force != true && options.verifyHashes != true && sameMtime && cached.outputHash != null
					&& FileSystem.exists(target) && !FileSystem.isDirectory(target)) {
					next.set(relative, cached);
					files.push(relative);
					revisions.push(relative + ":" + cached.outputHash);
					reused++;
					continue;
				}
				if (encoder == null)
					encoder = findEncoder(options.encoder);
				if (encoder == "")
					throw "找不到 ASTC 编码器，请安装 hx-astcenc 或配置 encoder";
				if (settings == null)
					settings = Sha256.encode("hxmaker-astc-1|" + encoderIdentity(encoder, options.verifyHashes == true)
						+ "|-cl|" + block + "|" + quality + "|" + premultiply + "|zlib:" + zlib + "|level:" + zlibLevel);
				var sameStat:Bool = cached != null && cached.size == stat.size && cached.mtime == stat.mtime.getTime();
				var hash:String = sameStat && options.verifyHashes != true ? cached.hash : Sha256.make(File.getBytes(input)).toHex();
				var dimensions:{width:Int, height:Int} = readPngSize(input);
				var signature:String = Sha256.encode(hash + "|" + settings);
				var valid:Bool = options.force != true && sameMtime && cached.signature == signature
					&& FileSystem.exists(target) && !FileSystem.isDirectory(target)
					&& FileSystem.stat(target).size == cached.outputSize
					&& FileSystem.stat(target).mtime.getTime() == cached.outputMtime
					&& validOutput(target, dimensions.width, dimensions.height, zlib);
				if (valid && options.verifyHashes == true)
					valid = Sha256.make(File.getBytes(target)).toHex() == cached.outputHash;
				var outputHash:String;
				if (valid) {
					reused++;
					outputHash = cached.outputHash;
				} else {
					temporary = target + "." + uniqueSuffix() + ".tmp.astc";
					FileSystem.createDirectory(Path.directory(target));
					var args:Array<String> = ["-cl", input, temporary, block, quality];
					if (premultiply)
						args.push("-pp-premultiply");
					if (Sys.command(encoder, args) != 0 || !validOutput(temporary, dimensions.width, dimensions.height))
						throw "ASTC 编码失败或输出校验失败";
					if (zlib) {
						var compressed:Bytes = Compress.run(File.getBytes(temporary), zlibLevel);
						File.saveBytes(temporary, compressed);
						if (!validOutput(temporary, dimensions.width, dimensions.height, true))
							throw "ASTC 外层 zlib 压缩校验失败";
					}
					outputHash = Sha256.make(File.getBytes(temporary)).toHex();
					replaceFile(temporary, target);
					converted++;
				}
				var outputStat:sys.FileStat = FileSystem.stat(target);
				next.set(relative, {size: stat.size, mtime: stat.mtime.getTime(), hash: hash, signature: signature,
					outputSize: outputStat.size, outputMtime: outputStat.mtime.getTime(), outputHash: outputHash});
				files.push(relative);
				revisions.push(relative + ":" + outputHash);
			} catch (error:Dynamic) {
				failed++;
				if (temporary != null)
					deleteIfExists(temporary);
				// 该输出路径由本生成器管理，转换失败时不能让打包工具误用过期纹理。
				deleteIfExists(target);
				Sys.println("[ASTC] 使用原图片：" + input + "，" + Std.string(error));
				if (options.strict == true)
					throw error;
			}
		}
		for (relative in previous.keys()) {
			if (!next.exists(relative) && isSafeRelative(relative) && StringTools.endsWith(relative, ".png"))
				deleteIfExists(Path.join([output, relative.substr(0, relative.length - 4) + ".astc"]));
		}
		writeIfChanged(cachePath, Json.stringify({schemaVersion: 1, entries: next}));
		var manifest:ASTCManifestData = {schemaVersion: 1, prefix: prefix, revision: Sha256.encode(revisions.join("\n")), files: files};
		Sys.println('[ASTC] ${prefix}：复用 ${reused}，生成 ${converted}，回退 ${failed}');
		return {output: output, manifest: manifest};
	}

	/** 只允许安全的游戏相对路径前缀。 */
	public static function normalizePrefix(prefix:String):String {
		if (prefix == null)
			throw "ASTC 资源前缀不能为空";
		prefix = StringTools.replace(prefix, "\\", "/");
		while (StringTools.startsWith(prefix, "./"))
			prefix = prefix.substr(2);
		while (StringTools.endsWith(prefix, "/"))
			prefix = prefix.substr(0, prefix.length - 1);
		if (prefix != "" && !isSafeRelative(prefix))
			throw "ASTC 资源前缀必须是相对路径：" + prefix;
		return prefix;
	}

	/** 扫描 PNG；不跟随指向源目录外部的符号链接。 */
	private static function scan(root:String, relative:String, files:Array<String>, realRoot:String, ?ancestors:Map<String, Bool>):Void {
		if (ancestors == null)
			ancestors = [];
		var directory:String = Path.join([root, relative]);
		var realDirectory:String = FileSystem.fullPath(directory);
		if (ancestors.exists(realDirectory))
			return;
		ancestors.set(realDirectory, true);
		for (name in FileSystem.readDirectory(directory)) {
			if (StringTools.startsWith(name, "."))
				continue;
			var child:String = relative == "" ? name : relative + "/" + name;
			if (!isSafeRelative(child))
				continue;
			var full:String = Path.join([root, child]);
			var real:String = Path.normalize(FileSystem.fullPath(full));
			if (!StringTools.startsWith(real, realRoot + "/"))
				continue;
			if (FileSystem.isDirectory(full))
				scan(root, child, files, realRoot, ancestors);
			else if (StringTools.endsWith(child, ".png"))
				files.push(child);
		}
		ancestors.remove(realDirectory);
	}

	/** 检查缓存记录中的相对路径，防止删除非生成目录的文件。 */
	private static function isSafeRelative(path:String):Bool {
		return path != "" && !Path.isAbsolute(path) && path.indexOf(":") < 0 && path.indexOf("\\") < 0
			&& path.split("/").indexOf("..") < 0 && path.split("/").indexOf(".") < 0;
	}

	/** 缓存损坏时视作首次构建。 */
	private static function readCache(path:String):DynamicAccess<ASTCCacheEntry> {
		try {
			if (FileSystem.exists(path)) {
				var data:{schemaVersion:Int, entries:DynamicAccess<ASTCCacheEntry>} = Json.parse(File.getContent(path));
				if (data.schemaVersion == 1 && data.entries != null)
					return data.entries;
			}
		} catch (error:Dynamic) {}
		return {};
	}

	/** 从 PNG 文件头读取尺寸，不在宏中解码整张图片。 */
	private static function readPngSize(path:String):{width:Int, height:Int} {
		var input:sys.io.FileInput = File.read(path, true);
		var bytes:Bytes;
		try { bytes = input.read(24); } catch (error:Dynamic) { input.close(); throw error; }
		input.close();
		if (bytes.get(0) != 137 || bytes.getString(1, 3) != "PNG" || bytes.getString(12, 4) != "IHDR")
			throw "PNG 文件头无效";
		var width:Int = (bytes.get(16) << 24) | (bytes.get(17) << 16) | (bytes.get(18) << 8) | bytes.get(19);
		var height:Int = (bytes.get(20) << 24) | (bytes.get(21) << 16) | (bytes.get(22) << 8) | bytes.get(23);
		if (width <= 0 || height <= 0)
			throw "PNG 尺寸无效";
		return {width: width, height: height};
	}

	/** 裸 ASTC 只读取文件头；zlib 输出先有界解压，再核对完整长度和源图片尺寸。 */
	private static function validOutput(path:String, width:Int, height:Int, zlib:Bool = false):Bool {
		if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
			return false;
		if (zlib) {
			try {
				var bytes:Bytes = File.getBytes(path);
				return ASTCFormat.isZlib(bytes) && ASTCFormat.isValid(ASTCFormat.decode(bytes), null, width, height);
			} catch (error:Dynamic) {
				return false;
			}
		}
		var input:sys.io.FileInput = File.read(path, true);
		var header:Bytes;
		try { header = input.read(16); } catch (error:Dynamic) { input.close(); return false; }
		input.close();
		return ASTCFormat.isValid(header, FileSystem.stat(path).size, width, height);
	}

	/** 查找显式指定、环境变量或 hx-astcenc 中的编码器；Windows 默认使用 SSE2 版本。 */
	private static function findEncoder(configured:Null<String>):String {
		var candidates:Array<String> = [];
		var overridePath:String = configured ?? Sys.getEnv("HXMAKER_ASTCENC");
		if (overridePath != null)
			candidates.push(overridePath);
		else {
			try {
				var process:Process = new Process("haxelib", ["path", "hx-astcenc"]);
				var paths:String = process.stdout.readAll().toString();
				process.stderr.readAll();
				process.exitCode();
				process.close();
				for (line in paths.split("\n")) {
					line = StringTools.trim(line);
					if (line == "" || StringTools.startsWith(line, "-"))
						continue;
					while (StringTools.endsWith(line, "/") || StringTools.endsWith(line, "\\"))
						line = line.substr(0, line.length - 1);
					candidates.push(Path.join([Path.directory(line), "tools", Sys.systemName() == "Windows" ? "astcenc-sse2.exe" : "astcenc"]));
				}
			} catch (error:Dynamic) {}
			var systemPath:String = Sys.getEnv("PATH");
			if (systemPath != null)
				for (directory in systemPath.split(Sys.systemName() == "Windows" ? ";" : ":"))
					candidates.push(Path.join([directory, Sys.systemName() == "Windows" ? "astcenc.exe" : "astcenc"]));
		}
		for (candidate in candidates)
			if (FileSystem.exists(candidate) && !FileSystem.isDirectory(candidate))
				return FileSystem.fullPath(candidate);
		return "";
	}

	/** 编码器路径、大小和修改时间参与缓存；严格模式同时校验二进制内容。 */
	private static function encoderIdentity(path:String, strict:Bool):String {
		if (path == "")
			return "missing";
		var stat:sys.FileStat = FileSystem.stat(path);
		return path + ":" + stat.size + ":" + stat.mtime.getTime() + (strict ? ":" + Sha256.make(File.getBytes(path)).toHex() : "");
	}

	/** 内容未变化时不重写缓存，减少文件系统操作。 */
	public static function writeIfChanged(path:String, content:String):Void {
		if (FileSystem.exists(path) && File.getContent(path) == content)
			return;
		FileSystem.createDirectory(Path.directory(path));
		var temporary:String = path + "." + uniqueSuffix() + ".tmp";
		File.saveContent(temporary, content);
		replaceFile(temporary, path);
	}

	/** 替换经过验证的临时文件，兼容 Windows 不覆盖现有文件的行为。 */
	private static function replaceFile(source:String, target:String):Void {
		if (Sys.systemName() == "Windows")
			deleteIfExists(target);
		FileSystem.rename(source, target);
	}

	/** 避免同时构建时共用同一个临时文件。 */
	private static function uniqueSuffix():String {
		return StringTools.replace(Std.string(Sys.time()), ".", "_") + "_" + Std.random(0x3fffffff);
	}

	/** 只清理指定文件；不存在或清理失败不阻断原图片回退。 */
	private static function deleteIfExists(path:String):Void {
		try {
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path))
				FileSystem.deleteFile(path);
		} catch (error:Dynamic) {}
	}
}

/** 构建结果可直接供宏和平台资源登记使用。 */
typedef ASTCBuildResult = {
	var output:String;
	var manifest:ASTCManifestData;
}

/** 编码缓存不打入游戏，仅记录源文件和输出状态。 */
private typedef ASTCCacheEntry = {
	var size:Int;
	var mtime:Float;
	var hash:String;
	var signature:String;
	var outputSize:Int;
	var outputMtime:Float;
	var outputHash:String;
}
#end
