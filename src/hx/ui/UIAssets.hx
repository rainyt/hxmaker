package hx.ui;

import hx.macro.MacroTools;
import hx.macro.UIMoudle;
import haxe.io.Path;
import hx.display.DisplayObject;
import hx.assets.StringFuture;
import hx.assets.Assets;
import hx.display.DisplayObjectContainer;

class UIAssets extends Assets {
	/**
	 * 模块映射
	 */
	public static var moudle:UIMoudle = new UIMoudle(MacroTools.readContent("./moudle.xml"));

	private var __path:String;

	private var __dirPath:String;

	/**
	 * 界面配置
	 */
	public var viewXml:Xml;

	public function new(path:String) {
		super();
		__path = path;
		__dirPath = Path.directory(__path);
	}

	override function start() {
		var id = Assets.formatName(__path);
		if (strings.exists(id)) {
			viewXml = Xml.parse(strings.get(id));
			parseXml(viewXml);
			__start();
			return;
		}
		// 这里需要解析这个xml所需要的所有资源
		new StringFuture(__path).onComplete((xml:String) -> {
			viewXml = Xml.parse(xml);
			parseXml(viewXml);
			__start();
		}).onError(errorValue);
	}

	private function parseXml(xml:Xml):Void {
		for (item in xml.elements()) {
			// 判断是否需要加载资源
			trace(item.nodeName);
			if (item.nodeName.indexOf("xml:") == 0) {
				// 需要加载xml配置
				var nodeName = item.nodeName;
				nodeName = StringTools.replace(nodeName, "xml:", "");
				this.loadUIAssets(Path.join([__dirPath, nodeName + ".xml"]));
			} else {
				switch item.nodeName {
					case "MovieClip":
						// 加载精灵图
						var path = item.get("src");
						this.loadAtlas(path, StringTools.replace(path, ".png", ".xml"));
					case "spine":
						// 加载Spine动画
						var path = item.get("path");
						this.loadSpineAtlas(path + ".png", path + ".atlas");
						this.loadString(path + ".json");
					case "bitmapData":
						// 加载位图
						var path = item.get("path");
						this.loadBitmapData(path);
					case "sound":
						// 加载音频
						var path = item.get("path");
						this.loadSound(path);
					case "atlas":
						// 加载精灵图
						var path = item.get("path");
						this.loadAtlas(path + ".png", path + ".xml");
					case "Image", "Button":
						// 加载图片
						if (item.exists("src")) {
							var url = item.get("src");
							if (url.indexOf(":") == -1)
								this.loadBitmapData(url);
						}
				}
				if (item.exists("style")) {
					var style = item.get("style");
					if (style.indexOf(":") != -1) {
						this.loadStyle(Path.join([__dirPath, style.split(":")[0] + ".xml"]));
					}
				}
			}
			parseXml(item);
		}
	}

	private function __start() {
		super.start();
	}

	/**
	 * 开始构造布局
	 * @param parent 
	 */
	public function build(parent:DisplayObjectContainer, createRoot:Bool = false):DisplayObject {
		var parentXml = viewXml.nodeType == Document ? viewXml.firstElement() : viewXml;
		var ids = Reflect.getProperty(parent, "ids");
		if (createRoot) {
			var display = buildItem(parentXml, parent, ids, false);
			if (display is DisplayObjectContainer) {
				parent = cast display;
			} else {
				return parent;
			}
		}
		// 对父节点进行属性绑定
		UIManager.getInstance().applyAttributes(parent, parentXml, this);
		buildUi(parentXml, parent, ids);
		return parent;
	}

	public function buildItem(item:Xml, parent:DisplayObjectContainer, ids:Map<String, DisplayObject>, autoBuildUi:Bool = true):DisplayObject {
		if (item.get("load") == "true")
			return null;
		var classType = UIManager.getInstance().getClassType(item.nodeName);
		if (classType != null) {
			var ui:DisplayObject = UIManager.getInstance().createInstance(classType, item);
			parent.addChild(ui);
			// 应用属性
			UIManager.getInstance().applyAttributes(ui, item, this);
			if (ui.name != null && ids != null) {
				ids.set(ui.name, ui);
			}
			if (autoBuildUi && ui is DisplayObjectContainer) {
				buildUi(item, cast ui, ids);
			}
			return ui;
		} else {
			// 检查是否为xml:配置格式
			if (item.nodeName.indexOf("xml:") == 0) {
				var ui = StringTools.replace(item.nodeName, "xml:", "");
				if (moudle.classed.exists(ui)) {
					var type = Type.resolveClass(moudle.classed.get(ui).className);
					var uiDisplay:DisplayObject = UIManager.getInstance().createInstance(type, item);
					parent.addChild(uiDisplay);
					UIManager.getInstance().applyAttributes(uiDisplay, item, this);
					if (uiDisplay.name != null && ids != null) {
						ids.set(uiDisplay.name, uiDisplay);
					}
				} else {
					// 需要检查moudle模块
					for (key => assets in this.uiAssetses) {
						if (key == ui) {
							var parent = assets.build(parent, true);
							if (parent is DisplayObjectContainer) {
								buildUi(item, cast parent, ids);
							}
							UIManager.getInstance().applyAttributes(parent, item, this);
							if (parent.name != null && ids != null) {
								ids.set(parent.name, parent);
							}
							return parent;
						}
					}
				}
			}
		}
		return null;
	}

	public function buildUi(xml:Xml, parent:DisplayObjectContainer, ids:Map<String, DisplayObject>):Void {
		for (item in xml.elements()) {
			buildItem(item, parent, ids);
		}
	}
}
