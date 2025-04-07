package project;

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
}
