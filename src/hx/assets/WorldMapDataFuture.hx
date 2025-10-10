package hx.assets;

import haxe.Json;
import hx.assets.StringFuture;
import hx.assets.StyleFuture.StyleAssets;
import hx.assets.Future;

using haxe.io.Path;

/**
 * 加载世界地图资源
 */
class WorldMapDataFuture extends Future<StyleAssets, String> {
	override function post() {
		var path = getLoadData();
		var dir = path.directory().directory();
		new StringFuture(getLoadData()).onComplete(map -> {
			var mapData = Json.parse(map);
			var files:Array<{
				id:String
			}> = mapData.files;
			var assets = new StyleAssets();
			assets.objects.set(path.withoutExtension().withoutDirectory(), mapData);
			for (file in files) {
				var config = WorldObjectData.current.getConfig(file.id);
				switch config.type {
					case "png":
						assets.loadBitmapData(Path.join([dir, config.path]));
					default:
						throw "unknown type" + config.type;
				}
			}
			assets.onComplete(a -> {
				this.completeValue(assets);
			}).onError(errorValue);
			assets.start();
		}).onError(this.errorValue);
	}
}
