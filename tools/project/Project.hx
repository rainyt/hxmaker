package project;

import haxe.Template;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;

class Project {
	public function new() {}

	public function getProjectName():String {
		return null;
	}

	public function export(outputPath:String):Void {
		trace("Exporting project to " + outputPath);
		var directory = Path.directory(Sys.programPath());
		var projectDir = Path.join([directory, "tools/templates/" + getProjectName()]);
		trace("Project directory: " + projectDir);
		saveTo(projectDir, outputPath);
	}

	public function saveTo(srcFile:String, destFile:String):Void {
		trace("Copying from " + srcFile + " to " + destFile);
		if (FileSystem.isDirectory(srcFile)) {
			var files = FileSystem.readDirectory(srcFile);
			for (file in files) {
				if (file.indexOf(".") == 0) {
					continue;
				}
				var path = Path.join([srcFile, file]);
				saveTo(path, Path.join([destFile, file]));
			}
		} else {
			var dir = Path.directory(destFile);
			if (!FileSystem.exists(dir)) {
				FileSystem.createDirectory(dir);
			}
			var file = Path.extension(srcFile);
			switch (file) {
				case "hx", "xml":
					// 实现模板
					var data = new Template(File.getContent(srcFile));
					File.saveContent(destFile, data.execute(getProjectData()));
				default:
					File.copy(srcFile, destFile);
			}
		}
	}

	public function getProjectData():Dynamic {
		return {};
	}

	public function build(args:Array<String>):Void {}
}
