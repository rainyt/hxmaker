package hx.ui;

import hx.display.DisplayObject;
import hx.utils.StringFuture;
import hx.utils.Assets;
import hx.display.DisplayObjectContainer;

class UIAssets extends Assets {
	private var __path:String;

	/**
	 * 界面配置
	 */
	public var viewXml:Xml;

	public function new(path:String) {
		super();
		__path = path;
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
			switch item.nodeName {
				case "atlas":
					// 加载精灵图
					var path = item.get("path");
					this.loadAtlas(path + ".png", path + ".xml");
				case "Image":
					// 加载图片
					if (item.exists("src")) {
						var url = item.get("src");
						if (url.indexOf(":") == -1)
							this.loadBitmapData(url);
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
	public function build(parent:DisplayObjectContainer):Void {
		var parentXml = viewXml.nodeType == Document ? viewXml.firstElement() : viewXml;
		buildUi(parentXml, parent);
	}

	public function buildUi(xml:Xml, parent:DisplayObjectContainer):Void {
		for (item in xml.elements()) {
			var classType = UIManager.getInstance().getClassType(item.nodeName);
			if (classType != null) {
				var ui:DisplayObject = Type.createInstance(classType, []);
				parent.addChild(ui);
				trace("构造", ui);
				// 应用属性
				UIManager.getInstance().applyAttributes(ui, item, this);
				if (ui is DisplayObjectContainer) {
					buildUi(item, cast ui);
				}
			}
		}
	}
}
