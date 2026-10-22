package procedure;

import app.GameContext;
import hx.procedure.IProcedure;

/** 示例流程只依赖业务上下文，不直接操作后端。 */
class SampleProcedure implements IProcedure {
	private var context:GameContext;
	private var name:String;
	public function new(context:GameContext, name:String) { this.context = context; this.name = name; }
	public function onInit():Void { context.audit.log(name+".onInit"); }
	public function onEnter():Void { context.audit.log(name+".onEnter"); }
	public function onUpdate(dt:Float):Void {}
	public function onLeave():Void { context.audit.log(name+".onLeave"); }
	public function onDestroy():Void { context.audit.log(name+".onDestroy"); }
}
