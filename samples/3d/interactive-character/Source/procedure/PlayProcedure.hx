package procedure;

import app.GameContext;
import game.CharacterScene;

/** 角色业务更新的唯一入口，Scene 的显示树更新不再次推进动画。 */
class PlayProcedure extends SampleProcedure {
	public function new(context:GameContext) { super(context,"Play"); }
	override public function onEnter():Void {
		super.onEnter();
		if (context.session == null || !context.session.ready) throw "游戏流程需要有效的已加载资源会话";
		context.world = new CharacterScene(context,context.session.source); context.show(context.world);
	}
	override public function onUpdate(dt:Float):Void { if (context.world != null) context.world.step(dt); }
	override public function onLeave():Void {
		context.releaseScene(); context.world = null; context.releaseSession(); super.onLeave();
	}
}
