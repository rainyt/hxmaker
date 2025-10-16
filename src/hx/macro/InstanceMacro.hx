package hx.macro;

import haxe.macro.Expr.TypePath;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

#if macro
/**
 * 为当前类型自动生成一个单例`getInstance()`访问方法
 */
class InstanceMacro {
	public static function build():Array<Field> {
		var array = Context.getBuildFields();
		var currentType = TypeTools.toComplexType(Context.getLocalType());
		var t:TypePath = {
			name: Context.getLocalClass().get().name,
			pack: Context.getLocalClass().get().pack
		}
		var getInstance = macro {
			if (__instance == null) {
				__instance = new $t();
			}
			return __instance;
		}
		// 单例对象
		var shader:Field = {
			name: "__instance",
			kind: FVar(currentType),
			pos: Context.currentPos(),
			access: [AStatic, APrivate]
		}
		array.push(shader);
		// 单例方法
		var func:Field = {
			name: "getInstance",
			kind: FFun({
				args: [],
				expr: getInstance,
				ret: currentType
			}),
			access: [AStatic, APublic],
			pos: Context.currentPos()
		}
		array.push(func);
		return array;
	}
}
#end
