package hx.macro;

#if macro
import sys.FileSystem;
#end
import haxe.macro.Expr.ExprOf;

/**
 * 宏工具
 */
class MacroTools {
	/**
	 * 编译时的时间
	 * @return String
	 */
	macro public static function buildDateTime():ExprOf<String> {
		return macro $v{Date.now().toString()};
	}

	/**
	 * 读取文本数据
	 * @param path 
	 * @return ExprOf<String>
	 */
	macro public static function readContent(path:String):ExprOf<String> {
		if (!FileSystem.exists(path)) {
			return macro $v{null};
		}
		return macro $v{sys.io.File.getContent(path)};
	}
}
