package app;

import game.CharacterScene;
import hx.display.Scene;
import hx.display.Stage;
import hx.procedure.ProcedureManager;
import procedure.MenuProcedure;
import procedure.LoadingProcedure;
import procedure.PlayProcedure;
import procedure.ErrorProcedure;

/** 协调流程、场景和资源所有权；异步回调只排队，不直接重入流程切换。 */
class GameContext {
	public var config(default, null):SampleConfig = new SampleConfig();
	public var audit(default, null):SampleAudit;
	public var manager(default, null):ProcedureManager;
	public var state(default, null):SampleState;
	public var session(default, null):CharacterAssetSession;
	public var world:CharacterScene;
	public var errorMessage:String = "";
	public var failNextLoad:Bool = false;
	public var disposed(default, null):Bool = false;
	public var hasPending(get, never):Bool;
	private var stage:Stage;
	private var scene:Scene;
	private var pending:SampleState;
	private function get_hasPending():Bool { return pending != null; }
	public function new(stage:Stage, audit:SampleAudit) {
		this.stage = stage; this.audit = audit; audit.flowsCreated++; audit.log("创建独立 ProcedureManager");
		manager = new ProcedureManager();
		manager.registerProcedure(new MenuProcedure(this)); manager.registerProcedure(new LoadingProcedure(this));
		manager.registerProcedure(new PlayProcedure(this)); manager.registerProcedure(new ErrorProcedure(this));
		pending = SampleState.MENU;
	}
	public function update(dt:Float):Void {
		if (disposed) return;
		if (pending != null) {
			var next = pending; pending = null;
			if (next != state) {
				state = next;
				try {
					switch (next) {
						case MENU: manager.switchProcedure(MenuProcedure);
						case LOADING: manager.switchProcedure(LoadingProcedure);
						case PLAYING: manager.switchProcedure(PlayProcedure);
						case ERROR: manager.switchProcedure(ErrorProcedure);
					}
				} catch (error:Dynamic) {
					errorMessage = "创建或切换场景失败："+Std.string(error); audit.fail(errorMessage);
					releaseScene(); releaseSession(); pending = SampleState.ERROR;
				}
			}
		}
		// 每帧只处理一个待切换状态；onEnter 的同步回调留到下一帧。
		if (!disposed && pending == null) {
			try { manager.update(dt); } catch (error:Dynamic) {
				errorMessage = "业务更新失败："+Std.string(error); audit.fail(errorMessage);
				if (world != null) world.suspendInput(); pending = SampleState.ERROR;
			}
		}
	}
	public function requestLoading(simulateFailure:Bool = false):Void {
		if (disposed || state == SampleState.LOADING) return;
		if (world != null) world.suspendInput();
		failNextLoad = simulateFailure; pending = SampleState.LOADING;
	}
	public function requestMenu():Void {
		if (disposed) return;
		if (world != null) world.suspendInput();
		// 取消意图立即生效，防止下一次 update 之前加载回调抢回游戏状态。
		if (state == SampleState.LOADING) releaseSession();
		pending = SampleState.MENU;
	}
	public function createSession():CharacterAssetSession {
		releaseSession(); session = new CharacterAssetSession(audit); return session;
	}
	public function ownsLoading(value:CharacterAssetSession):Bool {
		return value != null && !disposed && state == SampleState.LOADING && session == value && !value.disposed && pending == null;
	}
	public function readyForPlay(value:CharacterAssetSession):Void { if (ownsLoading(value) && value.ready) pending = SampleState.PLAYING; }
	public function loadingError(value:CharacterAssetSession, message:String, simulated:Bool = false):Void {
		if (!ownsLoading(value)) return;
		errorMessage = message;
		if (simulated) { audit.injectedFailures++; audit.log("演示故障："+message); } else audit.fail(message);
		pending = SampleState.ERROR;
	}
	public function show(value:Scene):Void {
		releaseScene(); scene = value; stage.addChildAt(value,0);
	}
	public function releaseScene():Void {
		var previous = scene; scene = null;
		if (previous != null) { if (previous.parent != null) previous.parent.removeChild(previous); previous.dispose(); }
	}
	public function releaseSession():Void { if (session != null) { var previous = session; session = null; previous.dispose(); } }
	public function report():Dynamic { return {state:state == null ? "未进入" : Std.string(state),pending:pending == null ? null : Std.string(pending),audit:audit.snapshot()}; }
	public function dispose():Void {
		if (disposed) return;
		disposed = true; pending = null;
		// onLeave 先销毁世界，再释放会话；最后的调用覆盖尚未进入流程的异常路径。
		manager.destroy(); releaseScene(); releaseSession(); world = null;
		audit.flowsDisposed++; audit.log("销毁独立 ProcedureManager"); stage = null;
	}
}
