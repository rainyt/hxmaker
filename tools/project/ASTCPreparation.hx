package project;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

/** 在 OpenFL 收集发布资源之前执行配置的 ASTC 宏，避免首次构建遗漏生成文件。 */
class ASTCPreparation {
	/** 使用 OpenFL 自身解析条件和 include，取得当前目标实际生效的宏。 */
	public static function prepare(xml:Xml, projectPath:String, target:String, flags:Array<String>):Void {
		var root:Xml = xml.firstElement();
		if (!containsConfiguration(Path.join([projectPath, "project.xml"]), []))
			return;
		var work:String = Path.join([projectPath, ".hxmaker", "astc"]);
		FileSystem.createDirectory(work);
		var projectFile:String = Path.join([projectPath, ".project.xml"]);
		var app:Xml = null;
		for (element in root.elementsNamed("app")) {
			app = element;
			break;
		}
		if (app == null)
			throw "ASTC 构建准备需要 project.xml 中的 app 配置";
		var originalOutput:String = app.get("path");
		// display 在输出目录已有 HXML 时会读取旧文件，使用独立目录取得本次最新配置。
		app.set("path", Path.join([work, "display"]));
		File.saveContent(projectFile, xml.toString());
		var display:String;
		try {
			display = capture("haxelib", ["run", "openfl", "display", projectFile, target].concat(flags));
		} catch (error:Dynamic) {
			restoreApp(app, originalOutput);
			File.saveContent(projectFile, xml.toString());
			throw error;
		}
		restoreApp(app, originalOutput);
		File.saveContent(projectFile, xml.toString());
		var expressions:Array<String> = [];
		var pattern:EReg = ~/^--macro\s+(.+)$/;
		for (line in display.split("\n")) {
			line = StringTools.trim(line);
			if (!pattern.match(line))
				continue;
			var expression:String = pattern.matched(1);
			if (expression.indexOf("hx.marco.ASTCMarco.build(") >= 0)
				expressions.push(expression);
		}
		if (expressions.length == 0)
			return;
		var assetFile:String = Path.join([work, "prepared-assets.xml"]);
		File.saveContent(assetFile, "<project />");
		var arguments:Array<String> = ["--no-output", "-lib", "hxmaker", "-D", "hxmaker_astc_assets=" + assetFile];
		for (expression in expressions) {
			arguments.push("--macro");
			arguments.push(expression);
		}
		if (Sys.command("haxe", arguments) != 0)
			throw "ASTC 构建准备失败，停止本次发布";
		var include:Xml = Xml.createElement("include");
		include.set("path", assetFile);
		root.addChild(include);
		File.saveContent(projectFile, xml.toString());
	}

	/** 只检测项目及其相对 include；条件判断由后续 OpenFL display 完成。 */
	private static function containsConfiguration(file:String, visited:Map<String, Bool>):Bool {
		if (!FileSystem.exists(file) || FileSystem.isDirectory(file))
			return false;
		file = FileSystem.fullPath(file);
		if (visited.exists(file))
			return false;
		visited.set(file, true);
		var content:String = File.getContent(file);
		if (content.indexOf("hx.marco.ASTCMarco.build") >= 0)
			return true;
		var xml:Xml = Xml.parse(content);
		return containsInclude(xml, Path.directory(file), visited);
	}

	/** 遍历 section 中的 include，避免遗漏分平台配置。 */
	private static function containsInclude(xml:Xml, directory:String, visited:Map<String, Bool>):Bool {
		for (child in xml.elements()) {
			if (child.nodeName == "include" && child.exists("path")) {
				var path:String = child.get("path");
				if (containsConfiguration(Path.isAbsolute(path) ? path : Path.join([directory, path]), visited))
					return true;
			}
			if (containsInclude(child, directory, visited))
				return true;
		}
		return false;
	}

	/** 恢复实际游戏输出目录，display 目录不参与正式构建。 */
	private static function restoreApp(app:Xml, output:Null<String>):Void {
		if (output == null)
			app.remove("path");
		else
			app.set("path", output);
	}

	/** 读取 HXML 文本并检查子进程结果，参数不经过 shell 拼接。 */
	private static function capture(command:String, arguments:Array<String>):String {
		var process:Process = new Process(command, arguments);
		var output:String = process.stdout.readAll().toString();
		var error:String = process.stderr.readAll().toString();
		var code:Int = process.exitCode();
		process.close();
		if (code != 0)
			throw "读取 OpenFL 构建配置失败：" + error + output;
		return output;
	}
}
