package hx.ui;

import haxe.io.Path;
import hx.display.DisplayObject;
import hx.assets.StringFuture;
import hx.assets.Assets;
import hx.display.DisplayObjectContainer;

class UIAssets extends Assets {
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

	/**
	 * 加载样式
	 * @param xml 
	 */
	public function loadStyle(xml:String):Void {
		pushFuture(new hx.assets.StyleFuture(xml, false));
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
			var display = buildItem(parentXml, parent, ids);
			if (display is DisplayObjectContainer) {
				parent = cast display;
			} else {
				return parent;
			}
		}
		buildUi(parentXml, parent, ids);
		return parent;
	}

	public function buildItem(item:Xml, parent:DisplayObjectContainer, ids:Map<String, DisplayObject>):DisplayObject {
		var classType = UIManager.getInstance().getClassType(item.nodeName);
		if (classType != null) {
			var ui:DisplayObject = Type.createInstance(classType, []);
			parent.addChild(ui);
			// trace("构造", ui);
			// 应用属性
			UIManager.getInstance().applyAttributes(ui, item, this);
			if (ui.name != null) {
				ids.set(ui.name, ui);
			}
			if (ui is DisplayObjectContainer) {
				buildUi(item, cast ui, ids);
			}
			return ui;
		} else {
			// 检查是否为xml:配置格式
			if (item.nodeName.indexOf("xml:") == 0) {
				trace("属于配置文件");
				var ui = StringTools.replace(item.nodeName, "xml:", "");
				for (key => assets in this.uiAssetses) {
					if (key == ui) {
						var parent = assets.build(parent);
						if (parent is DisplayObjectContainer) {
							buildUi(item, cast parent, ids);
						}
						return parent;
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
