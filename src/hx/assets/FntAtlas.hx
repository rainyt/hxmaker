package hx.assets;

import hx.display.BitmapData;

class FntAtlas extends Atlas {
	public var __xml:Xml;

	public var chars:Map<String, FntChar> = [];

	public function new(bitmapData:BitmapData, xml:Xml) {
		super(bitmapData);
		__xml = xml;
		this.parser();
	}

	override function parser() {
		super.parser();
		try {
			if (__xml.firstElement().nodeType == Document) {
				__xml = __xml.firstElement();
			}
		} catch (e) {
			trace("异常", __xml);
		}
		var items = __xml.firstElement().elements();
		while (items.hasNext()) {
			var item = items.next();
			if (item.nodeName == "chars") {
				for (char in item.elements()) {
					trace(char.toString());
					var id:Int = Std.parseInt(char.get("id"));
					var posx:Float = Std.parseFloat(char.get("x"));
					var posy:Float = Std.parseFloat(char.get("y"));
					var pwidth:Float = Std.parseFloat(char.get("width"));
					var pheight:Float = Std.parseFloat(char.get("height"));
					var xadvance:Int = Std.parseInt(char.get("xadvance"));
					var xoffset:Float = Std.parseFloat(char.get("xoffset"));
					var yoffset:Float = Std.parseFloat(char.get("yoffset"));
					var str = String.fromCharCode(id);
					chars.set(str, {
						id: id,
						x: posx,
						y: posy,
						width: pwidth,
						height: pheight,
						xadvance: xadvance,
						xoffset: xoffset,
						yoffset: yoffset
					});
					var newBitmapData = this.bitmapData.sub(posx, posy, pwidth, pheight);
					this.bitmapDatas.set(str, newBitmapData);
				}
			}
		}
	}
}

typedef FntChar = {
	var id:Int;
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var xadvance:Int;
	var xoffset:Float;
	var yoffset:Float;
}
