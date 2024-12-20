package hx.utils;

import haxe.Json;
import hx.events.FutureErrorEvent;
import haxe.Exception;

class JsonFuture extends Future<Dynamic, String> {
	override function post() {
		super.post();
		new StringFuture(this.getLoadData()).onComplete(text -> {
			try {
				var object = Json.parse(text);
				this.completeValue(object);
			} catch (err:Exception) {
				this.errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "json parser error."));
			}
		}).onError(errorValue);
	}
}
