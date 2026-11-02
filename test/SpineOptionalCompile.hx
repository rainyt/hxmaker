package;

import hx.assets.Assets;
import hx.events.SpineEvent;
import hx.ui.UIManager;

/** 未引入 Spine 库时，普通资源、界面与事件类型仍可被编译引用。 */
class SpineOptionalCompile {
	static function main():Void {
		var assets:Assets = new Assets();
		var event:SpineEvent = new SpineEvent(SpineEvent.START);
		UIManager.bindAssets(assets);
		trace(event);
	}
}
