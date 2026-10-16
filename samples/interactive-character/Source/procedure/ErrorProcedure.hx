package procedure;

import app.GameContext;
import ui.StatusScene;

class ErrorProcedure extends SampleProcedure {
	public function new(context:GameContext) { super(context,"Error"); }
	override public function onEnter():Void {
		super.onEnter();
		var panel = new StatusScene("进入场景失败",[
			{text:"重试正常加载",action:() -> context.requestLoading()},
			{text:"返回菜单",action:context.requestMenu}
		]);
		context.show(panel); panel.setMessage(context.errorMessage);
	}
	override public function onLeave():Void { context.releaseScene(); super.onLeave(); }
}
