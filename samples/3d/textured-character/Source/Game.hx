package;

import hx.display.Label;
import hx.display.Stage;
import hx.events.MouseEvent;
import test.CharacterRender;

/** 标准 hxmaker 舞台，负责示例场景的创建与释放。 */
class Game extends Stage {
	private var current:CharacterRender;
	override public function onStageInit():Void {
		super.onStageInit();
		showCharacter();
		var reload = new Label("销毁并重新进入场景");
		reload.x = 24; reload.y = 785; reload.fontSize = 16; reload.color = 0x8ed6ff;
		reload.addEventListener(MouseEvent.CLICK, function(_) { showCharacter(); });
		addChild(reload);
	}
	private function showCharacter():Void {
		if (current != null) { removeChild(current); current.dispose(); }
		current = new CharacterRender(); addChildAt(current, 0);
	}
}
