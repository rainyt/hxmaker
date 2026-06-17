package hx.assets;

import haxe.Json;
import hx.events.FutureErrorEvent;
import haxe.Exception;

class JsonFuture extends Future<Dynamic, String> {
	override function post() {
		super.post();
		new StringFuture(this.getLoadData()).onComplete(text -> {
				this.addAssetObject(text);
			try {
				var object = Json.parse(text.data);
				this.completeValue(object);
			} catch (err:Exception) {
				this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "json parser error.", this.getLoadData()));
			}
		}).onError(errorValue);
	}
}
