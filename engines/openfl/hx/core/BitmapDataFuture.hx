package hx.core;

import hx.events.FutureErrorEvent;
import openfl.utils.Assets;
import hx.displays.BitmapData;
import hx.utils.Future;

/**
 * 纹理加载器
 */
class BitmapDataFuture extends Future<BitmapData, String> {
	override function post() {
		super.post();
		Assets.loadBitmapData(this.getLoadData(), false).onComplete((data) -> {
			this.completeValue(BitmapData.formData(new OpenFlBitmapData(data)));
		}).onError(err -> {
			errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "load fail:" + this.getLoadData()));
		});
	}
}
