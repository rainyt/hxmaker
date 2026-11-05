package hx.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** 将构建指纹编译为常量，不在发布运行时读取文件或 Git。 */
class RenderBuildMacro {
	public static macro function buildId():haxe.macro.Expr {
		var value:String = haxe.macro.Context.definedValue("hxmaker_build_id");
		return macro $v{value == null ? "未记录构建指纹" : value};
	}
}
