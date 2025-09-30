package hx.ui;

import hx.core.Hxmaker;
import hx.display.Stage;
import hx.display.Quad;
import hx.display.MovieClip;
import hx.display.Spine;
import hx.display.ListView;
import hx.display.Scroll;
import hx.display.BitmapLabel;
import spine.SkeletonData;
import hx.display.Scene;
import hx.geom.Point;
import hx.geom.Rectangle;
import hx.utils.ScaleUtils;
import hx.assets.Sound;
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

	public static function clean():Void {
		for (assets in assetsList) {
			assets.clean();
		}
		assetsList = [];
	}

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
	 * 获得SkeletonData数据
	 * @param name spine名称
	 * @param json 如果不提供，则自动以name为命名获得
	 * @return SkeletonData
	 */
	public static function getSkeletonData(name:String, json:String = null):SkeletonData {
		for (assets in assetsList) {
			var data = assets.getSkeletonData(name, json);
			if (data != null) {
				return data;
			}
		}
		return null;
	}

	/**
	 * 获得样式xml
	 * @param id 
	 * @return Xml
	 */
	public static function getStyle(id:String):Xml {
		for (assets in assetsList) {
			var style = assets.styles.get(id);
			if (style != null) {
				return style;
			}
		}
		return null;
	}

	/**
	 * 读取纹理图集
	 * @param id 
	 * @return Atlas
	 */
	public static function getAtlas(id:String):Atlas {
		for (assets in assetsList) {
			var atlas = assets.getAtlas(id);
			if (atlas != null) {
				return atlas;
			}
		}
		return null;
	}

	/**
	 * 读取声音
	 * @param id 
	 * @return Sound
	 */
	public static function getSound(id:String):Sound {
		for (assets in assetsList) {
			var sound = assets.getSound(id);
			if (sound != null) {
				return sound;
			}
		}
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
	private var __createInstance:Map<String, Xml->DisplayObject> = [];

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
					case "blendMode":
						display.blendMode = xml.get("blendMode");
					default:
						var classType = UIAssets.moudle.getClassType(display);
						if (classType != null) {
							if (classType.attributes.exists(key))
								classType.attributes.get(key).setValue(display, xml.get(key));
						}
				}
			}
			if (useAnchor || percentHeight != null || percentWidth != null) {
				if (display.parent != null && display.parent.layout == null) {
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
			var textformat = createTextformat(xml);
			if (textformat != null) {
				obj.textFormat = textformat;
			}
			for (key in xml.attributes()) {
				switch key {
					case "src":
						var id = xml.getStringId("src");
						obj.skin = {
							up: getBitmapData(id) ?? assets.getBitmapData(id)
						};
					case "text":
						obj.text = xml.get("text");
					case "scale9Grid":
						var rect = xml.get("scale9Grid");
						var rects = rect.split(" ");
						var grid = new Rectangle(Std.parseFloat(rects[0]), Std.parseFloat(rects[1]), Std.parseFloat(rects[2]), Std.parseFloat(rects[3]));
						obj.scale9Grid = grid;
					case "labelOffsetPoint":
						var point = xml.get("labelOffsetPoint");
						var points = point.split(" ");
						obj.labelOffsetPoint = new Point(Std.parseFloat(points[0]), Std.parseFloat(points[1]));
				}
			}
		});
		addAttributesParse(Image, function(obj:Image, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var data = xml.get("src");
				data = Path.withoutDirectory(Path.withoutExtension(data));
				obj.data = getBitmapData(data) ?? assets.getBitmapData(data);
			}
			if (xml.get("fill") == "true") {
				var scale = ScaleUtils.mathScale(Hxmaker.engine.stageWidth, Hxmaker.engine.stageHeight, obj.width, obj.height);
				obj.scaleX = obj.scaleY = scale;
			}
			if (xml.exists("scale9Grid")) {
				var rect = xml.get("scale9Grid");
				var rects = rect.split(" ");
				var grid = new Rectangle(Std.parseFloat(rects[0]), Std.parseFloat(rects[1]), Std.parseFloat(rects[2]), Std.parseFloat(rects[3]));
				obj.scale9Grid = grid;
			}
		});
		addAttributesParse(BitmapLabel, function(obj:BitmapLabel, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var data = xml.get("src");
				data = Path.withoutDirectory(Path.withoutExtension(data));
				obj.atlas = getAtlas(data) ?? assets.atlases.get(data);
			}
			if (xml.exists("text")) {
				obj.data = xml.get("text");
			}
			if (xml.exists("fontName")) {
				obj.fontName = xml.get("fontName");
			}
			if (xml.exists("space")) {
				obj.space = Std.parseFloat(xml.get("space"));
			}
			if (xml.exists("hAlign")) {
				obj.horizontalAlign = xml.get("hAlign");
			}
			if (xml.exists("vAlign")) {
				obj.verticalAlign = xml.get("vAlign");
			}
		});
		addAttributesParse(Label, function(obj:Label, xml:Xml, assets:Assets) {
			if (xml.exists("text")) {
				obj.data = xml.get("text");
				var textformat = createTextformat(xml);
				if (textformat != null) {
					obj.textFormat = textformat;
				}
			}
			if (xml.exists("hAlign")) {
				obj.horizontalAlign = xml.get("hAlign");
			}
			if (xml.exists("vAlign")) {
				obj.verticalAlign = xml.get("vAlign");
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
		addAttributesParse(Scene, function(obj:Scene, xml:Xml, assets:Assets) {});
		addAttributesParse(Scroll, function(obj:Scroll, xml:Xml, assets:Assets) {});
		addAttributesParse(ListView, function(obj:ListView, xml:Xml, assets:Assets) {});
		addCreateInstance(Spine, function(xml:Xml):Spine {
			var id = xml.getStringId("src");
			var spine = new Spine(UIManager.getSkeletonData(id));
			return spine;
		});
		addAttributesParse(Spine, function(obj:Spine, xml:Xml, assets:Assets) {
			if (xml.exists("action")) {
				var id = xml.getStringId("action");
				obj.play(id);
			}
		});
		addAttributesParse(MovieClip, function(obj:MovieClip, xml:Xml, assets:Assets) {
			if (xml.exists("src")) {
				var id = xml.getStringId("src");
				var atlas = getAtlas(id);
				if (atlas != null) {
					var fps = xml.exists("fps") ? Std.parseInt(xml.get("fps")) : 12;
					var animate = xml.exists("action") ? xml.get("action") : "";
					obj.setBitmapDatas(atlas.getBitmapDatasByName(animate), fps);
					obj.play();
				}
			}
		});
		addAttributesParse(Quad, function(obj:Quad, xml:Xml, assets:Assets) {
			// color
			if (xml.exists("color")) {
				var color = xml.get("color");
				obj.data = Std.parseInt(color);
			}
		});
	}

	/**
	 * 创建单例
	 * @param classType 
	 * @param xml 
	 * @return Dynamic
	 */
	public function createInstance(classType:Class<Dynamic>, xml:Xml):Dynamic {
		var name = Type.getClassName(classType);
		var ui:DisplayObject = __createInstance.exists(name) ? __createInstance.get(name)(xml) : Type.createInstance(classType, []);
		return ui;
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

	public function addCreateInstance<T>(c:Class<T>, func:Xml->T):Void {
		var name = Type.getClassName(c);
		__createInstance.set(name, cast func);
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
		// 应用样式
		if (attributes.exists("style")) {
			var id = attributes.get("style");
			var xml = UIManager.getStyle(id);
			if (xml != null) {
				for (key in xml.attributes()) {
					if (!attributes.exists(key)) {
						attributes.set(key, xml.get(key));
					}
				}
			}
		}
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
			var uiAssets = getUIAssets(assets, id);
			if (uiAssets != null) {
				uiAssets.build(parent);
				break;
			}
		}
	}

	public function getUIAssets(assets:Assets, id:String):UIAssets {
		if (assets.uiAssetses.exists(id)) {
			return assets.uiAssetses.get(id);
		}
		for (assets in assets.uiAssetses) {
			var uiAssets = getUIAssets(assets, id);
			if (uiAssets != null) {
				return uiAssets;
			}
		}
		return null;
	}
}
