package hx.ui;

import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import haxe.io.Path;
import hx.utils.Assets;
import hx.display.Image;
import hx.display.DisplayObject;

using hx.utils.XmlTools;

class UIManager {
	@:noCompletion private static var __instance:UIManager;

	public static function getInstance() {
		if (__instance == null) {
			__instance = new UIManager();
		}
		return __instance;
	}

	private var __types:Map<String, Class<Dynamic>> = ["atlas" => null];

	private var __applyAttributes:Map<String, Dynamic->Xml->Assets->Void> = [];

	private function new() {
		__applyAttributes.set("default", (display:DisplayObject, xml:Xml, assets:Assets) -> {
			// 默认行为
			var useAnchor:Bool = false;
			for (key in xml.attributes()) {
				switch key {
					case "x":
						display.x = Std.parseFloat(xml.get("x"));
					case "y":
						display.y = Std.parseFloat(xml.get("y"));
					case "width":
						display.width = Std.parseFloat(xml.get("width"));
					case "height":
						display.height = Std.parseFloat(xml.get("height"));
					case "alpha":
						display.alpha = Std.parseFloat(xml.get("alpha"));
					case "scaleX":
						display.scaleX = Std.parseFloat(xml.get("scaleX"));
					case "scaleY":
						display.scaleY = Std.parseFloat(xml.get("scaleY"));
					case "rotation":
						display.rotation = Std.parseFloat(xml.get("rotation"));
					case "left", "right", "top", "bottom", "centerX", "centerY":
						// 意味着需要使用AnchorLayoutData数据
						useAnchor = true;
				}
			}
			if (useAnchor) {
				if (display.parent.layout == null) {
					display.parent.layout = new AnchorLayout();
				}
				display.layoutData = new AnchorLayoutData(xml.getFloatValue("top"), xml.getFloatValue("right"), xml.getFloatValue("bottom"),
					xml.getFloatValue("left"), xml.getFloatValue("centerX"), xml.getFloatValue("centerY"));
			}
		});
		addAttributesParse(Image, function(obj:Image, xml:Xml, assets:Assets) {
			if (xml.exists("data")) {
				var data = xml.get("data");
				data = Path.withoutDirectory(Path.withoutExtension(data));
				obj.data = assets.getBitmapData(data);
			}
		});
	}

	/**
	 * 添加属性解析支持
	 * @param c 
	 * @param func 
	 */
	public function addAttributesParse<T>(c:Class<T>, func:T->Xml->Assets->Void):Void {
		var name = Type.getClassName(c);
		__applyAttributes.set(name, cast func);
	}

	/**
	 * 根据名称获得对应的UI类型
	 * @param name 
	 * @return Class<Dynamic>
	 */
	public function getClassType(name:String):Class<Dynamic> {
		if (__types.exists(name)) {
			return __types.get(name);
		}
		var c = Type.resolveClass("hx.display." + name);
		if (c != null) {
			__types.set(name, c);
		}
		return c;
	}

	/**
	 * 应用资源属性
	 * @param ui 
	 * @param attributes 
	 */
	public function applyAttributes(ui:DisplayObject, attributes:Xml, assets:Assets):Void {
		var name = Type.getClassName(Type.getClass(ui));
		var parser = __applyAttributes.get(name);
		if (parser != null) {
			parser(ui, attributes, assets);
		}
		__applyAttributes.get("default")(ui, attributes, assets);
	}
}
