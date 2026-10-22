package procedure;

import app.CharacterAssetSession;
import app.GameContext;
import app.SampleState;
import ui.StatusScene;

/** 保留资源会话到游戏流程；取消、错误或退出时释放。 */
class LoadingProcedure extends SampleProcedure {
	private var panel:StatusScene;
	private var session:CharacterAssetSession;
	private var elapsed:Float = 0;
	private var simulateFailure:Bool = false;
	public function new(context:GameContext) { super(context,"Loading"); }
	override public function onEnter():Void {
		super.onEnter(); context.config.validate(); elapsed = 0; simulateFailure = context.failNextLoad; context.failNextLoad = false;
		panel = new StatusScene("正在通过 Assets 加载角色",[{text:"取消加载并返回菜单",action:context.requestMenu}]); context.show(panel);
		session = context.createSession(); var request = session;
		request.start(context.config,function() { context.audit.log("加载结果已就绪，等待流程更新交接"); },function(message:String) { context.loadingError(request,message); });
	}
	override public function onUpdate(dt:Float):Void {
		elapsed += dt;
		if (session == null || !context.ownsLoading(session)) return;
		panel.setMessage("加载进度："+Math.round(session.progress*100)+"%\n"+(session.ready ? "资源已就绪，准备进入场景。" : "等待 GLB 和内嵌图片解码。")
			+"\n可取消本次进入；资源缓存命中时同样经过流程交接。");
		if (session.ready && elapsed >= context.config.minimumLoadingSeconds) {
			if (simulateFailure) context.loadingError(session,"演示：资源已解码后主动中止。点击重试会走正常加载流程。",true);
			else context.readyForPlay(session);
		}
	}
	override public function onLeave():Void {
		context.releaseScene(); panel = null;
		if (context.state != SampleState.PLAYING || session == null || !session.ready) context.releaseSession();
		session = null; super.onLeave();
	}
}
