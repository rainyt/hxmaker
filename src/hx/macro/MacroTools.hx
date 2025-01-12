package hx.macro;

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
}
