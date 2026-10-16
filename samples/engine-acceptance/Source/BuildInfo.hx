package;

/** 在用户编译时读取版本标记，不执行外部命令。 */
class BuildInfo {
	public static macro function label():haxe.macro.Expr {
		var value=haxe.macro.Context.definedValue("hxmaker_baseline_label");
		return haxe.macro.Context.makeExpr(value == null ? "未标记，比较前请记录源码版本" : value,haxe.macro.Context.currentPos());
	}
	public static macro function versions():haxe.macro.Expr {
		return haxe.macro.Context.makeExpr({haxe:haxe.macro.Context.definedValue("haxe_ver"),
			openfl:haxe.macro.Context.definedValue("openfl"),lime:haxe.macro.Context.definedValue("lime"),
			hxmaker:haxe.macro.Context.definedValue("hxmaker"),hxmakerOpenfl:haxe.macro.Context.definedValue("hxmaker_openfl")},haxe.macro.Context.currentPos());
	}
}
