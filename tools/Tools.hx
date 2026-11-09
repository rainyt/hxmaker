import haxe.io.Path;
import project.Project;
import project.OpenFLProject;

class Tools {
	static function main() {
		var args = Sys.args();
		if (args.length <= 1) {
			throw "No arguments provided." + "\nUsage: hxmaker create <engine_name> <project_name>";
		}
		var command = args[0];
		var project = args[1];
		var projectName = args[2];
		if (projectName == null) {
			throw "No project name provided." + "\nUsage: hxmaker create <engine_name> <project_name>";
		}
		var project:Project = switch project {
			case "openfl":
				// Create OpenFL project
				new OpenFLProject();
			default:
				throw "Unknown project type: " + project;
		}
		switch (command) {
			case "prepare":
				// 只准备生成资源，供项目在资源包构建之前复用同一份宏配置。
				var prepareArgs:Array<String> = args.slice(2);
				prepareArgs.insert(prepareArgs.length - 1, "hxmaker_prepare_assets");
				project.build(prepareArgs);
			case "build":
				// 编译指定目标
				project.build(args.slice(2));
			case "create":
				project.export(Path.join([args[args.length - 1], projectName]));
		}
	}
}
