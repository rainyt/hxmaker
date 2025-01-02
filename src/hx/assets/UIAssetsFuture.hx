package hx.assets;

import hx.ui.UIAssets;

class UIAssetsFuture extends Future<UIAssets, String> {
	public var nativePath:String = "";

	override function post() {
		var uiAssets = new UIAssets(getLoadData());
		uiAssets.nativePath = nativePath;
		uiAssets.onComplete((data) -> {
			this.completeValue(cast data);
		}).onError(this.errorValue);
		uiAssets.start();
	}
}
