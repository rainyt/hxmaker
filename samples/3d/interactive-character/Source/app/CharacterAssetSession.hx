package app;

import hx.assets.Assets;
import hx.assets.ModelAsset;

/** 一次 Assets 加载会话；释放后仍接收终态，以清理无法中止的在途结果。 */
class CharacterAssetSession {
	public var source(default, null):ModelAsset;
	public var ready(default, null):Bool = false;
	public var disposed(default, null):Bool = false;
	public var progress(default, null):Float = 0;
	private var request:Assets;
	private var audit:SampleAudit;
	private var started:Bool = false;
	private var settled:Bool = false;
	private var success:Void->Void;
	private var failure:String->Void;
	public function new(audit:SampleAudit) { this.audit = audit; audit.sessionsCreated++; audit.log("创建资源会话"); }
	public function start(config:SampleConfig, onReady:Void->Void, onError:String->Void):Void {
		if (started || disposed) throw "资源会话只能启动一次";
		started = true; success = onReady; failure = onError;
		var name = config.assetName, assets = new Assets(); request = assets; assets.tryLoadTimes = 0;
		audit.loadsInFlight++; audit.log("Assets 开始加载："+config.assetPath);
		try {
			assets.loadModel(config.assetPath);
			assets.onProgress(value -> { if (!disposed) progress = value; });
			assets.onComplete(_ -> {
				settle();
				if (disposed) { audit.lateResults++; assets.clean(); audit.log("清理已取消会话的迟到结果"); return; }
				try {
					source = assets.getModel(name);
					if (source == null || !source.texturesReady) throw "GLB 或内嵌贴图尚未准备完成";
				} catch (error:Dynamic) { handleError(Std.string(error)); return; }
				ready = true; progress = 1; audit.log("Assets 加载完成");
				var callback = success; success = null; failure = null;
				if (callback != null) callback();
			});
			assets.onError(error -> { settle(); if (disposed) { audit.lateResults++; assets.clean(); return; } handleError(error.error); });
			assets.start();
		} catch (error:Dynamic) { settle(); handleError(Std.string(error)); }
	}
	private function settle():Void { if (!settled) { settled = true; audit.loadsInFlight--; } }
	private function handleError(message:String):Void {
		if (disposed) { if (request != null) request.clean(); return; }
		ready = false; source = null; request.stop(); request.clean();
		var callback = failure; success = null; failure = null;
		if (callback != null) callback(message);
	}
	public function dispose():Void {
		if (disposed) return;
		disposed = true; ready = false; source = null; success = null; failure = null;
		if (request != null) { request.stop(); request.clean(); }
		audit.sessionsDisposed++; audit.log("释放资源会话"+(started && !settled ? "，等待在途终态清理" : ""));
	}
}
