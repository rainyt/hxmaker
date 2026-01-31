package hx.assets;

import hx.ui.UIAssets;

class UIAssetsFuture extends Future<UIAssets, String> {
	public var nativePath:String = "";

	private var parentUIAssets:Assets;

	public function new(data:String, autoPost:Bool, ?parentUIAssets:Assets) {
		this.parentUIAssets = parentUIAssets;
		super(data, autoPost);
	}

	override function post() {
		var uiAssets = new UIAssets(getLoadData());
		uiAssets.parent = parentUIAssets;
		uiAssets.tryLoadTimes = 0;
		uiAssets.nativePath = nativePath;
		uiAssets.onComplete((data) -> {
			this.completeValue(cast data);
		}).onError(this.errorValue);
		uiAssets.start();
	}
}
