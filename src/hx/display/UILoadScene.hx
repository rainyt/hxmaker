package hx.display;

import hx.ui.UIManager;
import hx.ui.UIAssets;

/**
 * UI自动载入界面场景支持
 */
class UILoadScene extends Scene {
	public var uiAssets:UIAssets;

	public function new() {
		super();
	}

	/**
	 * 构造UI
	 */
	override private function __buildUi():Void {
		if (uiAssets == null) {
			// 检测是否存在__ui_id__，如果存在则需要通过UIManager进行构造
			var __ui_id__ = Reflect.getProperty(this, "__ui_id__");
			if (__ui_id__ != null) {
				uiAssets = new UIAssets(__ui_id__);
				UIManager.bindAssets(uiAssets);
				uiAssets.onComplete((e) -> {
					trace("加载完成");
					uiAssets.build(this);
					this.onLoaded();
				}).onError(err -> {});
				uiAssets.start();
			}
		}
	}

	public function onLoaded():Void {}

	override function dispose() {
		super.dispose();
		UIManager.unbindAssets(uiAssets);
	}
}
