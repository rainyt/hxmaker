package project;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.Process;

/** 生成标准 Unity 工程，并复用独立后端的构建和 C# 导出工具。 */
class UnityProject extends Project {
	private var backendPath:String;

	public function new() {
		super();
		var process:Process = new Process("haxelib", ["libpath", "hxmaker-unity"]);
		var output:String = StringTools.trim(process.stdout.readAll().toString());
		var code:Int = process.exitCode();
		process.close();
		if (code != 0 || output == "" || !FileSystem.exists(Path.join([output, "unity/package.json"])))
			throw "请先安装 hxmaker-unity，或使用 haxelib dev hxmaker-unity <后端目录> 登记本地后端。";
		backendPath = FileSystem.fullPath(output);
	}

	override public function getProjectName():String { return "unity"; }

	override public function getProjectData():Dynamic {
		return {
			project_name: Sys.args()[2],
			unity_runtime_json: Json.stringify("file:" + StringTools.replace(Path.join([backendPath, "unity"]), "\\", "/")),
			unity_builder_json: Json.stringify(Path.join([backendPath, "tools/build_unity.py"]))
		};
	}

	override public function build(args:Array<String>):Void {
		var directory:String = args.pop();
		var python:String = Sys.systemName() == "Windows" ? "python" : "python3";
		var options:Array<String> = [Path.join([backendPath, "tools/build_unity.py"]), "--project", directory];
		for (argument in args) options.push(argument);
		var code:Int = Sys.command(python, options);
		if (code != 0) Sys.exit(code);
	}
}
