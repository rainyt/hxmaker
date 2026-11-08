package hx.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr.Field;
#end

/** 编译期校验 Spine 依赖；运行时和渲染路径由库自带的条件宏选择。 */
class SpineMacro {
	#if macro
	public static function configure():Void {
		var hasHx:Bool = Context.defined("spine-hx") || Context.defined("spine_hx");
		var hasHaxe:Bool = Context.defined("spine-haxe") || Context.defined("spine_haxe");
		if (hasHx && hasHaxe)
			Context.error("Spine 运行时冲突：spine-hx 与 spine-haxe 只能引入一个。", Context.currentPos());
		if (hasHx)
			checkVersion("spine_hx", "3.8");
		if (hasHaxe)
			checkVersion("spine_haxe", "4.2");
	}

	private static function checkVersion(library:String, expected:String):Void {
		var version:String = Context.definedValue(StringTools.replace(library, "_", "-"));
		if (version == null)
			version = Context.definedValue(library);
		// 开发版没有可靠的版本号，保留由调用方使用源码适配的能力。
		if (version != null && ~/^[0-9]+\.[0-9]+/.match(version)
			&& version != expected && !StringTools.startsWith(version, expected + "."))
			Context.error(library + " 当前版本为 " + version + "，hxmaker 此适配需要 " + expected + ".x。", Context.currentPos());
	}

	/** 直接通过源码或 HXML 使用时也执行校验，不依赖 OpenFL 的 include.xml。 */
	public static function build():Array<Field> {
		configure();
		return Context.getBuildFields();
	}
	#end
}
