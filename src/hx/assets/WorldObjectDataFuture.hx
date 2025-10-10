package hx.assets;

import haxe.Json;

/**
 * 加载world_objects.json配置文件支持
 */
class WorldObjectDataFuture extends Future<WorldObjectData, String> {
	override function post() {
		new StringFuture(this.path).onComplete((text) -> {
			WorldObjectData.current = new WorldObjectData(Json.parse(text));
			this.completeValue(WorldObjectData.current);
		}).onError(this.errorValue);
	}
}
