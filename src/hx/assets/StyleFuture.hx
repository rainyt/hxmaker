package hx.assets;

class StyleFuture extends Future<StyleAssets, String> {
	override function post() {
		super.post();
		new StringFuture(getLoadData()).onComplete(data -> {
			var xml = Xml.parse(data);
			var assets = new StyleAssets();
			var nameId = Assets.formatName(this.getLoadData());
			for (item in xml.firstElement().elements()) {
				trace("样式：", item);
				assets.styles.set(nameId + ":" + item.nodeName, item);
				if (item.exists("src")) {
					assets.loadBitmapData(item.get("src"));
				}
			}
			assets.onComplete((data) -> {
				completeValue(assets);
			}).onError(errorValue);
			assets.start();
		}).onError(errorValue);
	}
}

/**
 * 样式资源
 */
class StyleAssets extends Assets {}
