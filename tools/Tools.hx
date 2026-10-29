import haxe.io.Path;
import project.Project;
import project.OpenFLProject;
import project.UnityProject;
import sys.FileSystem;

class Tools {
	public static function main():Void {
		try {
			run(Sys.args());
		} catch (error:Dynamic) {
			Sys.stderr().writeString(Std.string(error) + "\n");
			Sys.exit(1);
		}
	}

	private static function run(args:Array<String>):Void {
		var usage:String = "用法：hxmaker create <openfl|unity> <项目名>\n      hxmaker build <openfl|unity> [构建参数]";
		if (args.length < 2) throw usage;
		var directory:String = Sys.getCwd();
		// haxelib run 会在末尾附加调用者目录，不将其当作项目名或构建参数。
		var last:String = args[args.length - 1];
		if (args.length > (args[0] == "create" ? 3 : 2) && FileSystem.exists(last) && FileSystem.isDirectory(last)) {
			directory = FileSystem.fullPath(args.pop());
		}
		var command:String = args[0];
		if (command != "create" && command != "build") throw "未知命令：" + command + "\n" + usage;
		var project:Project = switch args[1] {
			case "openfl": new OpenFLProject();
			case "unity": new UnityProject();
			default: throw "未知后端：" + args[1] + "\n" + usage;
		};
		if (command == "create") {
			if (args.length != 3 || !~/^[A-Za-z_][A-Za-z0-9_-]*$/.match(args[2]))
				throw "请提供有效的项目名，只能包含英文字母、数字、下划线和连字符。\n" + usage;
			var output:String = Path.join([directory, args[2]]);
			if (FileSystem.exists(output)) throw "目标路径已存在，不会覆盖：" + output;
			project.export(output);
			Sys.println("已创建项目：" + output);
		} else {
			var options:Array<String> = args.slice(2);
			options.push(directory);
			project.build(options);
		}
	}
}
