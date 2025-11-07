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
		var path = args.pop();
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
		File.saveContent(Path.join([path, ".project.xml"]), xml.toString());
		// 开始编译处理
		var cmd = "haxelib run openfl build " + Path.join([path, ".project.xml"]) + " " + args[0];
		if (args.indexOf("final") != -1) {
			cmd += " -final";
		}
		trace(cmd);
		Sys.command(cmd);
	}
}
