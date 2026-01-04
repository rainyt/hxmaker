package hx.macro;

#if macro
import haxe.macro.Expr.FieldType;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.Field;
import haxe.macro.Context;
import haxe.io.Path;
import haxe.macro.Expr.ComplexType;
import sys.FileSystem;
#end

/**
 * 自动导入所有类型，请使用：
 * @:build(zygame.macro.ImportAllClasses.build("源代码路径"))
 */
class AutoImport {
	#if macro
	macro public static function build(path:String, packageName:String = "game.levels"):Array<Field> {
		path = UIBuilder.moudle != null ? Path.join([UIBuilder.moudle.uibuildPath, path]) : path;
		if (!FileSystem.exists(path))
			path = "../../../../" + path;
		var files = FileSystem.readDirectory(path);
		var array = Context.getBuildFields();
		for (hxfile in files) {
			if (hxfile.indexOf(".hx") == -1)
				continue;
			hxfile = StringTools.replace(hxfile, ".hx", "");
			var t = TPath({
				pack: packageName.split("."),
				name: hxfile
			});
			array.push({
				name: "_" + hxfile,
				access: [Access.APrivate, Access.AStatic],
				kind: FieldType.FVar(t),
				pos: Context.currentPos()
			});
		}
		return array;
	}
	#end
}
