package hx.core;

import hx.utils.LoadData;
import hx.displays.BitmapData;
import hx.events.FutureErrorEvent;
import openfl.Assets;
import hx.utils.atlas.XmlAtlas;
import hx.utils.Future;

/**
 * 加载纹理图集
 */
class TextureAtlasFuture extends Future<XmlAtlas, TextureAtlasFutureLoadData> {
	override function post() {
		super.post();
		var data:TextureAtlasFutureLoadData = getLoadData();
		Assets.loadBitmapData(data.png, false).onComplete(bitmapData -> {
			Assets.loadText(data.xml).onComplete(xmlString -> {
				var xml = Xml.parse(xmlString);
				var xmlAtlas = new XmlAtlas(BitmapData.formData(new OpenFlBitmapData(bitmapData)), xml);
				xmlAtlas.parser();
				completeValue(xmlAtlas);
			}).onError(e -> {
				this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Xml file load fail."));
			});
		}).onError(e -> {
			this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "Png file load fail."));
		});
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
