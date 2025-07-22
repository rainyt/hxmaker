package hx.assets;

import hx.events.FutureErrorEvent;
import haxe.Exception;
import hx.assets.XmlAtlas;

class TextureAtlasFuture extends Future<XmlAtlas, TextureAtlasFutureLoadData> {
	override function post() {
		super.post();
		var data:TextureAtlasFutureLoadData = getLoadData();
		new BitmapDataFuture(data.png).onComplete((bitmapData) -> {
			new StringFuture(data.xml).onComplete(xmlString -> {
				try {
					var xml = Xml.parse(xmlString);
					var xmlAtlas = new XmlAtlas(bitmapData, xml);
					completeValue(xmlAtlas);
				} catch (e:Exception) {
					this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "xml file " + this.path + " parse error:" + xmlString));
				}
			}).onError(this.errorValue);
		}).onError(this.errorValue);
	}
}

/**
 * 纹理加载配置
 */
typedef TextureAtlasFutureLoadData = {
	png:String,
	xml:String
} &
	LoadData;
