package hx.display;

import hx.ui.UIManager;
import hx.ui.UIAssets;

/**
 * UI自动载入界面场景支持
 */
class UILoadScene extends Scene {
	public var uiAssets:UIAssets;

	public var onLoadedEvent:FunctionListener = new FunctionListener();

	/**
	 * 是否正在构造中
	 */
	private var __supering__:Bool = false;

	private var __superOnLoaded__:Bool = false;

	public function new() {
		__supering__ = true;
		super();
		__supering__ = false;
		if (__superOnLoaded__) {
			this.onLoaded();
			this.onLoadedEvent.call();
		}
	}

	/**
	 * 构造UI
	 */
	override private function onBuildUI():Void {
		if (uiAssets == null) {
			// 检测是否存在__ui_id__，如果存在则需要通过UIManager进行构造
			var __ui_id__ = Reflect.getProperty(this, "__ui_id__");
			if (__ui_id__ != null) {
				uiAssets = new UIAssets(__ui_id__);
				UIManager.bindAssets(uiAssets);
				this.onLoad();
				uiAssets.onComplete((e) -> {
					uiAssets.build(this);
					if (!__supering__) {
						this.onLoaded();
						this.onLoadedEvent.call();
					} else {
						__superOnLoaded__ = true;
					}
				}).onError(err -> {});
				uiAssets.start();
			}
		}
	}

	/**
	 * 当需要自定义载入资源时使用
	 */
	public function onLoad():Void {}

	public function onLoaded():Void {}

	override function dispose() {
		super.dispose();
		UIManager.unbindAssets(uiAssets);
	}
}
