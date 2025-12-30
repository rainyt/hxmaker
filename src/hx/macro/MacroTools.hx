package hx.macro;

import haxe.macro.Context;
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

	/**
	 * 获取定义值
	 * @return ExprOf<Map<String,String>>
	 */
	macro public static function getDefines():ExprOf<Map<String, String>> {
		var obj:Map<String, String> = [];
		var map = Context.getDefines();
		for (key => value in map) {
			obj.set(key, value);
		}
		return Context.makeExpr(obj, Context.currentPos());
	}
}
