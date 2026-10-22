package;

import app.GameContext;
import app.SampleAudit;
import app.SampleState;
import hx.display.Label;
import hx.display.Stage;
import hx.events.MouseEvent;

/** 独立 ProcedureManager 只由本舞台更新；全局流程管理器不参与本示例。 */
class Game extends Stage {
	private var context:GameContext;
	private var audit:SampleAudit = new SampleAudit();
	private var summary:Label;
	private var restartRequested:Bool = false;
	private var cyclesRemaining:Int = 0;
	private var cycleExiting:Bool = false;
	private var hudTime:Float = 0;
	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true; context = new GameContext(this,audit);
		summary = new Label(""); summary.x = 24; summary.y = 743; summary.fontSize = 14; summary.color = 0xa9bad6; summary.mouseEnabled = false; addChild(summary);
		action("返回菜单",24,function() { stopCycles(); context.requestMenu(); });
		action("重新加载",184,function() { stopCycles(); context.requestLoading(); });
		action("重建流程",344,function() { stopCycles(); context.requestMenu(); restartRequested = true; });
		action("循环验收 ×5",504,function() { cyclesRemaining = 5; cycleExiting = false; context.requestMenu(); });
		action("停止循环",689,stopCycles);
		action("输出诊断 JSON",849,function() { trace("HXMAKER_INTERACTIVE_REPORT "+haxe.Json.stringify(context.report())); });
	}
	private function action(text:String,x:Float,callback:Void->Void):Void {
		var value = new Label(text); value.x = x; value.y = 784; value.fontSize = 17; value.color = 0x8ed6ff;
		value.addEventListener(MouseEvent.CLICK,function(_) { callback(); }); addChild(value);
	}
	private function stopCycles():Void { cyclesRemaining = 0; cycleExiting = false; }
	override public function onUpdate(dt:Float):Void {
		if (isDisposed || context == null) return;
		if (restartRequested) { restartRequested = false; context.dispose(); context = new GameContext(this,audit); }
		context.update(dt);
		if (cyclesRemaining > 0 && !context.hasPending) {
			if (context.state == SampleState.MENU) {
				if (cycleExiting) { cycleExiting = false; cyclesRemaining--; audit.cyclesCompleted++; }
				if (cyclesRemaining > 0) context.requestLoading();
			}
			else if (context.state == SampleState.ERROR) { stopCycles(); audit.log("循环因进入错误流程而停止"); }
			else if (context.state == SampleState.PLAYING && context.world != null && context.world.elapsed >= 1 && context.world.hasRendered) {
				cycleExiting = true; context.requestMenu();
			}
		}
		hudTime += dt;
		if (hudTime >= 0.2) {
			hudTime = 0; summary.data = "当前："+Std.string(context.state)+"　"+audit.summary()+"　循环剩余："+cyclesRemaining;
		}
		// 这里只更新显示树和 Scene3D 设置，不再次执行角色模拟。
		super.onUpdate(dt);
	}
	override public function dispose():Void { if (isDisposed) return; cyclesRemaining = 0; if (context != null) context.dispose(); super.dispose(); }
}
