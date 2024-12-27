package hx.ui;

import hx.display.TextFormat;
import hx.display.Label;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import haxe.io.Path;
import hx.utils.Assets;
import hx.display.Image;
import hx.display.DisplayObject;

using hx.utils.XmlTools;
using StringTools;

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
			var parent = display.parent;
			var useAnchor:Bool = false;
			var percentWidth:Null<Float> = null;
			var percentHeight:Null<Float> = null;
			for (key in xml.attributes()) {
				switch key {
					case "x":
						display.x = xml.getFloatValue("x");
					case "y":
						display.y = xml.getFloatValue("y");
					case "width":
						var value = xml.get("width");
						if (value.indexOf("%") != -1) {
							percentWidth = Std.parseFloat(value.replace("%", ""));
						} else {
							display.width = xml.getFloatValue("width");
						}
					case "height":
						var value = xml.get("height");
						if (value.indexOf("%") != -1) {
							percentHeight = Std.parseFloat(value.replace("%", ""));
						} else {
							display.height = xml.getFloatValue("height");
						}
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
			if (useAnchor || percentHeight != null || percentWidth != null) {
				if (display.parent.layout == null) {
					display.parent.layout = new AnchorLayout();
				}
				var layoutData = new AnchorLayoutData(xml.getFloatValue("top"), xml.getFloatValue("right"), xml.getFloatValue("bottom"),
					xml.getFloatValue("left"), xml.getFloatValue("centerX"), xml.getFloatValue("centerY"));
				display.layoutData = layoutData;
				layoutData.percentWidth = percentWidth;
				layoutData.percentHeight = percentHeight;
			}
		});
		addAttributesParse(Image, function(obj:Image, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var data = xml.get("src");
				data = Path.withoutDirectory(Path.withoutExtension(data));
				obj.data = assets.getBitmapData(data);
			}
		});
		addAttributesParse(Label, function(obj:Label, xml:Xml, assets:Assets) {
			if (xml.exists("text")) {
				obj.data = xml.get("text");
				var color = xml.get("color");
				var fontSize = xml.get("fontSize");
				if (color != null || fontSize != null) {
					var colorValue = color != null ? Std.parseInt(color) : 0x0;
					obj.textFormat = new TextFormat(null, fontSize != null ? Std.parseInt(fontSize) : 26, colorValue);
				}
				if (xml.exists("hAlign")) {
					obj.horizontalAlign = xml.get("hAlign");
				}
				if (xml.exists("vAlign")) {
					obj.verticalAlign = xml.get("vAlign");
				}
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
