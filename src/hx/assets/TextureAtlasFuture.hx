package hx.assets;

import hx.assets.XmlAtlas;

class TextureAtlasFuture extends Future<XmlAtlas, TextureAtlasFutureLoadData> {
	override function post() {
		super.post();
		var data:TextureAtlasFutureLoadData = getLoadData();
		trace("加载纹理", data);
		new BitmapDataFuture(data.png).onComplete((bitmapData) -> {
			new StringFuture(data.xml).onComplete(xmlString -> {
				var xml = Xml.parse(xmlString);
				var xmlAtlas = new XmlAtlas(bitmapData, xml);
				xmlAtlas.parser();
				completeValue(xmlAtlas);
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
