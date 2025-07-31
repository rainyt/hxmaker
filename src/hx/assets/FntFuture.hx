package hx.assets;

import hx.events.FutureErrorEvent;
import haxe.Exception;

class FntFuture extends Future<FntAtlas, FntFutureLoadData> {
	override function post() {
		super.post();
		var data:FntFutureLoadData = getLoadData();
		new BitmapDataFuture(data.png).onComplete((bitmapData) -> {
			new StringFuture(data.xml).onComplete(xmlString -> {
				try {
					var xml = Xml.parse(xmlString);
					var atlas = new FntAtlas(bitmapData, xml);
					completeValue(atlas);
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
typedef FntFutureLoadData = {
	png:String,
	xml:String
} &
	LoadData;
