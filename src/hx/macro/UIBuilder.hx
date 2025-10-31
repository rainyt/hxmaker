package hx.macro;

import haxe.Exception;
import sys.FileSystem;
import haxe.io.Path;
import haxe.macro.TypeTools;
import haxe.macro.Type.ClassType;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Var;
import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Expr.Field;

#if macro
class UIBuilder {
	/**
	 * 模块组件
	 */
	public static var moudle:UIMoudle;

	/**
	 * 构造一个XML布局
	 * @param xmlid 
	 * @return Array<Field>
	 */
	public static function build(path:String):Array<Field> {
		// 构造模块组件
		if (moudle == null && FileSystem.exists("./moudle.xml")) {
			moudle = new UIMoudle(File.getContent("./moudle.xml"));
		}
		// 绑定继承类
		var localClass = Context.getLocalClass().get();
		var fileds = Context.getBuildFields();
		// 将在该布局中新增ids的字段，以便访问
		fileds.push({
			name: "ids",
			kind: FVar(macro :Map<String, hx.display.DisplayObject>, macro new Map()),
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			pos: Context.currentPos()
		});
		// 追加一个__ui_id__属性，记录path
		fileds.push({
			name: "__ui_id__",
			kind: FVar(macro :String, macro $v{path}),
			meta: [
				{
					name: ":noCompletion",
					pos: Context.currentPos()
				}
			],
			pos: Context.currentPos(),
		});
		// 新增一个通过ids访问控件的函数
		fileds.push({
			name: "getChildById",
			kind: FFun({
				args: [
					{
						name: "id",
						type: macro :String
					}
				],
				expr: macro {
					return this.ids.get(id);
				}
			}),
			pos: Context.currentPos(),
		});
		var xml:Xml = Xml.parse(File.getContent(getPath(path)));
		var array = parseXmlFields(xml);
		fileds = fileds.concat(array);
		return fileds;
	}

	private static function getPath(path:String):String {
		if (FileSystem.exists(path))
			return path;
		var current = Sys.getCwd();
		for (i in 0...6) {
			var path = Path.join([current, path]);
			if (FileSystem.exists(path)) {
				return path;
			} else {
				current = Path.directory(current);
			}
		}
		return path;
	}

	/**
	 * 解析XML的节点定义实现
	 * @param xml 
	 * @return Array<Field>
	 */
	private static function parseXmlFields(xml:Xml):Array<Field> {
		var array:Array<Field> = [];
		for (item in xml.elements()) {
			if (item.exists("id")) {
				// trace("create field", item);
				var classPkgName = moudle != null ? moudle.getType(item.nodeName) : "hx.display." + item.nodeName;
				var type:haxe.macro.Type = null;
				try {
					type = Context.getType(classPkgName);
				} catch (e:Exception) {
					type = null;
				}
				var typePath:Dynamic = null;
				if (type != null) {
					var pkgs = classPkgName.split(".");
					var className = pkgs.pop();
					typePath = ComplexType.TPath({
						name: className,
						pack: pkgs
					});
				} else {
					typePath = ComplexType.TPath({
						name: "DisplayObject",
						pack: ["hx", "display"]
					});
				}
				array.push({
					name: item.get("id"),
					access: [APublic],
					kind: FProp("get", "null", typePath),
					pos: Context.currentPos()
				});
				array.push({
					name: "get_" + item.get("id"),
					access: [APrivate],
					kind: FFun({
						args: [],
						ret: typePath,
						expr: macro {
							return cast this.getChildById($v{item.get("id")});
						}
					}),
					meta: [
						{
							name: ":noCompletion",
							pos: Context.currentPos()
						}
					],
					pos: Context.currentPos()
				});
			}
			var fileds = parseXmlFields(item);
			if (fileds.length > 0) {
				array = array.concat(fileds);
			}
		}
		return array;
	}
}
#end
