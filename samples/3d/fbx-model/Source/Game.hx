package;

import hx.display.Stage;
import hx.display.Label;
import hx.events.MouseEvent;
import sample.ModelScene;

/** 舞台负责重新进入场景；模型加载和三维显示交给场景。 */
class Game extends Stage {
	private var current:ModelScene;

	override public function onStageInit():Void {
		super.onStageInit();
		enter();
		var button = new Label("销毁并重新进入场景");
		button.x = 24; button.y = 760; button.fontSize = 16; button.color = 0x8ed6ff;
		button.addEventListener(MouseEvent.CLICK, _ -> enter()); addChild(button);
	}

	private function enter():Void {
		if (current != null) { removeChild(current); current.dispose(); }
		current = new ModelScene(); addChildAt(current, 0);
	}
}
