package hx.utils.atlas;

import hx.gemo.Rectangle;
import hx.displays.BitmapData;

/**
 * 使用PNG + XML解析的图集支持
 */
class XmlAtlas extends Atlas {
	@:noCompletion private var __xml:Xml;

	public function new(bitmapData:BitmapData, xml:Xml) {
		super(bitmapData);
		__xml = xml;
	}

	override function parser() {
		super.parser();
		// 开始解析位图
		if (__xml.firstElement().nodeType == Document) {
			__xml = __xml.firstElement();
		}
		__xml = __xml.firstElement();
		var items = __xml.elements();
		while (items.hasNext()) {
			var item = items.next();
			var name = item.get("name");
			var x = Std.parseInt(item.get("x"));
			var y = Std.parseInt(item.get("y"));
			var width = Std.parseInt(item.get("width"));
			var height = Std.parseInt(item.get("height"));
			var newBitmapData = this.bitmapData.sub(x, y, width, height);
			if (item.exists("frameX") && item.exists("frameY") && item.exists("frameWidth") && item.exists("frameHeight")) {
				var frameX = Std.parseInt(item.get("frameX"));
				var frameY = Std.parseInt(item.get("frameY"));
				var frameWidth = Std.parseInt(item.get("frameWidth"));
				var frameHeight = Std.parseInt(item.get("frameHeight"));
				newBitmapData.frameRect = new Rectangle(frameX, frameY, frameWidth, frameHeight);
			}
			this.bitmapDatas.set(name, newBitmapData);
		}
	}
}
