package project;

import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;

class OpenFLProject extends Project {
	public function new() {
		super();
	}

	override function getProjectName():String {
		return "openfl";
	}

	override function export(outputPath:String) {
		super.export(outputPath);
		FileSystem.createDirectory(Path.join([outputPath, "Assets"]));
	}

	override function getProjectData():Dynamic {
		return {
			project_name: Sys.args()[2]
		}
	}

	override function build(args:Array<String>) {
		super.build(args);
		trace("Building OpenFL project with args: ", args);
		// 项目路径
		var path:String = FileSystem.fullPath(args.pop());
		// 复制project.xml命名为.project.xml文件到项目路径
		var xml:Xml = Xml.parse(File.getContent(Path.join([path, "project.xml"])));
		function addDefine(name:String):Void {
			var item = Xml.createElement("define");
			item.set("name", name);
			// item.set("value", value);
			xml.firstElement().insertChild(item, 0);
		}
		addDefine("hxmaker_project");
		for (define in args) {
			addDefine(define);
		}
		// 原生平台可能从生成的 Haxe 目录编译，宏始终以游戏项目根目录解析资源路径。
		var assetRoot:Xml = Xml.createElement("haxedef");
		assetRoot.set("name", "hxmaker_astc_project_root");
		assetRoot.set("value", path);
		xml.firstElement().addChild(assetRoot);
		File.saveContent(Path.join([path, ".project.xml"]), xml.toString());
		// 开始编译处理
		var flags:Array<String> = [];
		if (args.indexOf("final") != -1) {
			flags.push("-final");
		}
		if (args.indexOf("debug") != -1) {
			flags.push("-debug");
		}
		var current:String = Sys.getCwd();
		Sys.setCwd(path);
		var code:Int;
		try {
			ASTCPreparation.prepare(xml, path, args[0], flags);
			if (args.indexOf("hxmaker_prepare_assets") != -1) {
				Sys.setCwd(current);
				return;
			}
			code = Sys.command("haxelib", ["run", "openfl", "build", Path.join([path, ".project.xml"]), args[0]].concat(flags));
		} catch (error:Dynamic) {
			Sys.setCwd(current);
			throw error;
		}
		Sys.setCwd(current);
		if (code != 0)
			Sys.exit(code);
	}
}
