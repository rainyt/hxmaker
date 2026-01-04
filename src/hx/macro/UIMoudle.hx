package hx.macro;

#if macro
import sys.io.File;
import sys.FileSystem;
import haxe.macro.Context;
import sys.io.Process;
#end
import haxe.io.Path;

/**
 * UI模块数据
 */
class UIMoudle {
	/**
	 * 已定义的类型绑定
	 */
	public var classed:Map<String, MoudleClassType> = [];

	public var assetsFiles:Array<String> = [];

	public var uibuildPath:String;

	public function new(content:String, ?uibuildPath:String) {
		this.uibuildPath = uibuildPath;
		if (content == null) {
			return;
		}
		var xml = Xml.parse(content);
		for (item in xml.firstElement().elements()) {
			if (item.nodeName == "assets") {
				assetsFiles.push(uibuildPath != null ? Path.join([uibuildPath, item.get("path")]) : item.get("path"));
			} else
				classed.set(item.nodeName, new MoudleClassType(item));
		}
	}

	#if macro
	/**
	 * 获取UIBuilder路径
	 */
	public static function getUIBuilderPath():String {
		var definePath = Context.getDefines().get("ui_builder_path");
		if (definePath != null) {
			if (definePath.indexOf("<haxelib:") == 0) {
				// 说明是haxelib，格式为：<haxelib:name>/path
				var haxelibName = definePath.substring(9, definePath.indexOf(">"));
				var process = new Process("haxelib", ["libpath", haxelibName]);
				var output = process.stdout.readAll().toString();
				var haxelibPath = output.split("\n")[0];
				haxelibPath = StringTools.replace(haxelibPath, "\n", "");
				haxelibPath = StringTools.replace(haxelibPath, "\r", "");
				haxelibPath = haxelibPath + definePath.substring(definePath.indexOf("/") + 1);
				return haxelibPath;
			}
			return definePath;
		}
		return "";
	}

	/**
	 * 查询是否存在组件类型
	 * @param type 
	 * @return String
	 */
	public function getType(type:String):String {
		if (type.indexOf("xml:") == 0) {
			type = StringTools.replace(type, "xml:", "");
			if (!classed.exists(type)) {
				// 找不到时，应该访问xml文件
				for (file in assetsFiles) {
					var path = Path.join([file, type + ".xml"]);
					if (FileSystem.exists(path)) {
						var xml = Xml.parse(File.getContent(path));
						classed.set(type, new MoudleClassType("hx.display." + xml.firstElement().nodeName));
					}
				}
			}
		}
		if (classed.exists(type)) {
			return classed.get(type).className;
		}
		return "hx.display." + type;
	}
	#end

	public function getClassType(c:Dynamic):MoudleClassType {
		var cName = Type.getClassName(Type.getClass(c));
		if (cName == null)
			return null;
		cName = cName.split(".").pop();
		if (classed.exists(cName))
			return classed.get(cName);
		return null;
	}
}
