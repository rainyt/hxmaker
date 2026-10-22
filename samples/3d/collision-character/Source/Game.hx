package;

import hx.display.Label;
import hx.display.Stage;
import hx.events.MouseEvent;
import test.CollisionCharacterScene;

/** 舞台管理场景创建和销毁，便于检查输入与资源生命周期。 */
class Game extends Stage {
	private var current:CollisionCharacterScene;
	override public function onStageInit():Void {
		super.onStageInit(); showSample();
		var button = new Label("销毁并重新进入场景"); button.x = 24; button.y = 784; button.fontSize = 16; button.color = 0x8ed6ff;
		button.addEventListener(MouseEvent.CLICK,function(_) { showSample(); }); addChild(button);
	}
	private function showSample():Void {
		if (current != null) { removeChild(current); current.dispose(); }
		current = new CollisionCharacterScene(); addChildAt(current,0);
	}
}
