package procedure;

import app.GameContext;
import ui.MenuScene;

class MenuProcedure extends SampleProcedure {
	public function new(context:GameContext) { super(context,"Menu"); }
	override public function onEnter():Void { super.onEnter(); context.show(new MenuScene(context)); }
	override public function onLeave():Void { context.releaseScene(); super.onLeave(); }
}
