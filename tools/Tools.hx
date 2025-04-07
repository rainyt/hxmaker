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
		switch (command) {
			case "create":
				var project:Project = switch project {
					case "openfl":
						// Create OpenFL project
						new OpenFLProject();
					default:
						throw "Unknown project type: " + project;
				}
				project.export(Path.join([args[args.length - 1], projectName]));
		}
	}
}
