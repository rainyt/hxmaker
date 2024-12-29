package hx.utils;

import hx.ui.UIAssets;

class UIAssetsFuture extends Future<UIAssets, String> {
	override function post() {
		var uiAssets = new UIAssets(getLoadData());
		uiAssets.onComplete((data) -> {
			this.completeValue(cast data);
		}).onError(this.errorValue);
		uiAssets.start();
	}
}
