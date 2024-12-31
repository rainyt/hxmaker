package hx.ui;

import hx.assets.Atlas;
import hx.display.DisplayObjectContainer;
import hx.display.BitmapData;
import hx.display.HBox;
import hx.display.VBox;
import hx.display.Button;
import hx.display.TextFormat;
import hx.display.Label;
import hx.layout.AnchorLayout;
import hx.layout.AnchorLayoutData;
import haxe.io.Path;
import hx.assets.Assets;
import hx.display.Image;
import hx.display.DisplayObject;

using hx.utils.XmlTools;
using StringTools;

class UIManager {
	/**
	 * 资源列表
	 */
	private static var assetsList:Array<Assets> = [];

	/**
	 * 绑定资源
	 * @param assets 
	 */
	public static function bindAssets(assets:Assets) {
		if (assets != null) {
			assetsList.push(assets);
			@:privateAccess assets.__isBindAssets = true;
		}
	}

	/**
	 * 解除绑定资源
	 * @param assets 
	 */
	public static function unbindAssets(assets:Assets) {
		if (assets != null) {
			assetsList.remove(assets);
			@:privateAccess assets.__isBindAssets = false;
		}
	}

	/**
	 * 获得位图资源
	 * @param id 
	 * @return BitmapData
	 */
	public static function getBitmapData(id:String):BitmapData {
		for (assets in assetsList) {
			var bitmapData = assets.getBitmapData(id);
			if (bitmapData != null) {
				return bitmapData;
			}
		}
		trace("无法读取", id);
		return null;
	}

	/**
	 * 读取纹理图集
	 * @param id 
	 * @return Atlas
	 */
	public static function getAtlas(id:String):Atlas {
		for (assets in assetsList) {
			var atlas = assets.atlases.get(id);
			if (atlas != null) {
				return atlas;
			}
		}
		trace("无法读取", id);
		return null;
	}

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
					case "id":
						display.name = xml.get("id");
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
		addAttributesParse(Button, function(obj:Button, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var id = xml.getStringId("src");
				obj.skin = {
					up: getBitmapData(id) ?? assets.getBitmapData(id)
				};
			}
			obj.text = xml.get("text");
			var textformat = createTextformat(xml);
			if (textformat != null) {
				obj.textFormat = textformat;
			}
		});
		addAttributesParse(Image, function(obj:Image, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var data = xml.get("src");
				data = Path.withoutDirectory(Path.withoutExtension(data));
				obj.data = getBitmapData(data) ?? assets.getBitmapData(data);
			}
		});
		addAttributesParse(Label, function(obj:Label, xml:Xml, assets:Assets) {
			if (xml.exists("text")) {
				obj.data = xml.get("text");
				var textformat = createTextformat(xml);
				if (textformat != null) {
					obj.textFormat = textformat;
				}
				if (xml.exists("hAlign")) {
					obj.horizontalAlign = xml.get("hAlign");
				}
				if (xml.exists("vAlign")) {
					obj.verticalAlign = xml.get("vAlign");
				}
			}
		});
		addAttributesParse(VBox, function(obj:VBox, xml:Xml, assets:Assets) {
			if (xml.exists("gap")) {
				obj.gap = xml.getFloatValue("gap");
			}
		});
		addAttributesParse(HBox, function(obj:HBox, xml:Xml, assets:Assets) {
			if (xml.exists("gap")) {
				obj.gap = xml.getFloatValue("gap");
			}
		});
	}

	public function createTextformat(xml:Xml):TextFormat {
		var color = xml.get("color");
		var fontSize = xml.get("fontSize");
		if (color != null || fontSize != null) {
			var colorValue = color != null ? Std.parseInt(color) : 0x0;
			var textFormat = new TextFormat(null, fontSize != null ? Std.parseInt(fontSize) : 26, colorValue);
			return textFormat;
		}
		return null;
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

	/**
	 * 构造UI
	 * @param id 
	 * @param parent 
	 */
	public function buildUi(id:String, parent:DisplayObjectContainer):Void {
		var id = Path.withoutDirectory(Path.withoutExtension(id));
		for (assets in assetsList) {
			if (assets.uiAssetses.exists(id)) {
				assets.uiAssetses.get(id).build(parent);
				break;
			}
		}
	}
}
