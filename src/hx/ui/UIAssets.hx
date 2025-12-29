package hx.ui;

import hx.utils.Log;
import hx.utils.DisplayTools;
import hx.macro.MacroTools;
import hx.macro.UIMoudle;
import haxe.io.Path;
import hx.display.DisplayObject;
import hx.assets.StringFuture;
import hx.assets.Assets;
import hx.display.DisplayObjectContainer;

using haxe.io.Path;

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
			parserXmlString(strings.get(id));
			return;
		}
		var xmlString = UIManager.getString(id);
		if (xmlString != null) {
			parserXmlString(xmlString);
			return;
		}
		// 这里需要解析这个xml所需要的所有资源
		new StringFuture(__path).onComplete((xml:String) -> {
			// 缓存xml
			strings.set(id, xml);
			parserXmlString(xml);
		}).onError(errorValue);
	}

	private var __isParserXml:Bool = false;

	private function parserXmlString(xml:String):Void {
		if (!__isParserXml) {
			viewXml = Xml.parse(xml);
			parseXml(viewXml);
			__isParserXml = true;
		}
		__start();
	}

	private function parseXml(xml:Xml):Void {
		for (item in xml.elements()) {
			// 判断是否需要加载资源
			if (item.nodeName.indexOf("xml:") == 0) {
				// 需要加载xml配置
				var nodeName = item.nodeName;
				nodeName = StringTools.replace(nodeName, "xml:", "");
				this.loadUIAssets(Path.join([__dirPath, nodeName + ".xml"]));
			} else {
				switch item.nodeName {
					case "MovieClip":
						// 加载精灵图
						var path = item.get("src").withoutExtension();
						this.loadAtlas(path + ".png", path + ".xml");
					case "spine":
						// 加载Spine动画
						var path = item.get("path").withoutExtension();
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
					case "font":
						// 加载字体
						var path = item.get("path").withoutExtension();
						this.loadFnt(path + ".png", path + ".fnt");
					case "atlas":
						// 加载精灵图
						var path = item.get("path").withoutExtension();
						this.loadAtlas(path + ".png", path + ".xml");
					case "Image", "Button", "ImageLoader":
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
		var ids:Map<String, Dynamic> = Reflect.getProperty(parent, "ids");
		ids = ids == null ? new Map<String, Dynamic>() : ids;
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
		hx.utils.Timer.getInstance().nextFrame(() -> {
			for (object in ids) {
				if (object is UIAnimate) {
					var animate:UIAnimate = object;
					if (@:privateAccess !animate.__isAutoPlay) {
						@:privateAccess animate.__isAutoPlay = true;
						animate.updateOption();
						if (animate.auto) {
							animate.play(true);
						}
					}
				}
			}
		});
		return parent;
	}

	public static var ANIMATE_UID:Int = 0;

	/**
	 * 构建动画
	 */
	public function buildAnimate(item:Xml, parent:DisplayObjectContainer, ids:Map<String, Dynamic>, parentAnimateGroup:UIAnimateGroup = null):UIAnimate {
		var target = item.get("target");
		var display:DisplayObject = target == "this" ? parent : ids.get(target);
		if (display != null || item.nodeName == "animate-group") {
			var animate:UIAnimate = item.nodeName == "animate-group" ? new UIAnimateGroup(display, item) : new UIAnimate(display, item);
			if (item.get("auto") == "false")
				animate.auto = false;
			if (parentAnimateGroup != null) {
				parentAnimateGroup.addAnimate(animate);
			} else {
				if (item.exists("id")) {
					animate.id = item.get("id");
					ids.set(item.get("id"), animate);
				} else {
					ids.set("__animate__" + ANIMATE_UID++, animate);
				}
			}
			if (item.nodeName == "animate-group") {
				var group:UIAnimateGroup = cast animate;
				for (item in item.elements()) {
					if (item.nodeName == "animate") {
						var newAnimate = buildAnimate(item, parent, ids, group);
					}
				}
			}
			return animate;
		}
		return null;
	}

	public function buildItem(item:Xml, parent:DisplayObjectContainer, ids:Map<String, Dynamic>, autoBuildUi:Bool = true):DisplayObject {
		if (item.get("load") == "true")
			return null;

		if (item.nodeName == "animate" || item.nodeName == "animate-group") {
			var animate = buildAnimate(item, parent, ids);
			return null;
		}

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
					var __ui_id__ = Reflect.getProperty(uiDisplay, "__ui_id__");
					if (__ui_id__ != null) {
						var assetsUi = UIManager.getUIAssets(Assets.formatName(__ui_id__));
						if (assetsUi != null) {
							UIManager.getInstance().applyAttributes(uiDisplay, assetsUi.viewXml.firstElement(), this, true);
						}
					}
					UIManager.getInstance().applyAttributes(uiDisplay, item, this);
					if (uiDisplay.name != null && ids != null) {
						ids.set(uiDisplay.name, uiDisplay);
					}
					parent = cast uiDisplay;
					if (autoBuildUi && parent is DisplayObjectContainer) {
						buildUi(item, cast parent, ids);
					}
				} else {
					// 需要检查moudle模块
					var assets = UIManager.getUIAssets(ui);
					if (assets == null) {
						assets = this.uiAssetses.get(ui);
					}
					if (assets != null) {
						var parent = assets.build(parent, true);
						UIManager.getInstance().applyAttributes(parent, item, this);
						if (autoBuildUi && parent is DisplayObjectContainer) {
							buildUi(item, cast parent, ids);
						}
						if (parent.name != null && ids != null) {
							ids.set(parent.name, parent);
						}
						return parent;
					}
				}
			} else if (item.nodeName.indexOf("child:") == 0) {
				// 访问当前节点的子节点
				var name = item.nodeName.split(":")[1];
				var child:DisplayObject = null;
				DisplayTools.map(parent, (display) -> {
					if (display.name == name) {
						child = display;
						return false;
					}
					return true;
				});
				if (child != null && child is DisplayObjectContainer) {
					parent = cast child;
					buildUi(item, cast parent, ids);
				} else {
					trace("未找到子节点:" + name);
				}
			}
		}
		return null;
	}

	/**
	 * 遍历节点进行构造组件
	 * @param xml 
	 * @param parent 父节点容器 
	 * @param ids 映射表
	 */
	public function buildUi(xml:Xml, parent:DisplayObjectContainer, ids:Map<String, Dynamic>):Void {
		for (item in xml.elements()) {
			buildItem(item, parent, ids);
		}
	}
}
