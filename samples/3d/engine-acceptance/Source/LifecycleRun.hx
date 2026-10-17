package;

import hx.assets.Assets;
import hx.display.BitmapData;
import hx.display.DisplayObjectContainer;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.net.RequestQueue;

/** 独立资源循环；保留用户原缓存策略，只临时缩短本次释放等待，结束时恢复。 */
class LifecycleRun {
	public var busy(default,null):Bool = true;
	public var state(default,null):String = "准备";
	public var round(default,null):Int = 0;
	public var report(default,null):Dynamic;
	private var host:DisplayObjectContainer;
	private var assets:Assets;
	private var world:AcceptanceWorld;
	private var records:Array<Dynamic> = [];
	private var errors:Array<String> = [];
	private var bitmaps:Array<BitmapData> = [];
	private var started:Float;
	private var entered:Float;
	private var oldDelay:Float;
	private var initial:Dynamic;
	private var cancelled:Bool = false;
	private var loading:Bool = false;
	private var loadMs:Float = 0;
	private var done:Dynamic->Void;
	public function new(host:DisplayObjectContainer,done:Dynamic->Void) {
		this.host = host; this.done = done; started = MetricClock.now(); initial = RuntimeInfo.resources();
		oldDelay = RequestQueue.RELEASE_DELAY; RequestQueue.RELEASE_DELAY = 0.5;
	}
	public function start():Void { loadRound(); }
	private function loadRound():Void {
		if (cancelled || round >= 20) { state = "等待延迟回收"; entered = MetricClock.now(); return; }
		state = "加载"; loading = true; entered = MetricClock.now();
		var owner = new Assets(); assets = owner; owner.tryLoadTimes = 0;
		var dense = round%2 == 1, id = dense ? "robot-dense" : "robot";
		assets.loadModel("assets/"+id+".glb");
		assets.onError(error -> {
			if (!busy) { owner.stop(); owner.clean(); return; }
			loading = false; errors.push(error.error); clean(); finish(false,"资源加载失败");
		});
		assets.onComplete(_ -> {
			if (!busy) { owner.stop(); owner.clean(); return; }
			loadMs=MetricClock.now()-entered;
			loading = false;
			if (cancelled) { clean(); state = "等待延迟回收"; entered = MetricClock.now(); return; }
			try {
				var source = assets.getModel(id);
				for (i in 0...source.textureCount) { var bitmap = source.getTexture(i); if (bitmaps.indexOf(bitmap)<0) bitmaps.push(bitmap); }
				world = new AcceptanceWorld(assets,Cases.make("lifecycle","资源生命周期","actors",2,dense,true,true));
				host.addChild(world.layer); entered = MetricClock.now(); state = "绘制";
			} catch (error:Dynamic) { errors.push(Std.string(error)); clean(); finish(false,"实例创建失败"); }
		});
		assets.start();
	}
	public function tick(now:Float):Void {
		if (!busy) return;
		if (loading && now-entered > 15000) { errors.push("加载超时，迟到的结果将单独释放"); finish(false,"资源加载超时"); return; }
		if (world != null) world.update(1/60);
		if (state == "绘制") {
			if (world.scenes[0].stats.renderId > 0 && now-entered >= 250) {
				var heldGeometry:Array<Geometry3D> = [], heldMaterials:Array<Material3D> = [], heldScenes = world.scenes.copy();
				for (model in world.models) for (mesh in model.meshes) { heldGeometry.push(mesh.geometry); heldMaterials.push(mesh.material); }
				var loaded = RuntimeInfo.resources(); clean();
				var released = RuntimeInfo.resources();
				var disposed = true;
				for (geometry in heldGeometry) if (!geometry.isDisposed || geometry.referenceCount != 0) disposed = false;
				for (material in heldMaterials) if (!material.isDisposed || material.referenceCount != 0) disposed = false;
				for (scene in heldScenes) if (!scene.isDisposed) disposed = false;
				var refs = released.references == initial.references;
				if (!refs || !disposed) errors.push("第 "+(round+1)+" 轮释放后引用或对象状态异常");
				records.push({round:round+1,dense:round%2 == 1,loadMs:loadMs,loaded:loaded,released:released,referencesReturned:refs,objectsDisposed:disposed});
				round++; loadRound();
			} else if (now-entered > 10000) { errors.push("场景未完成绘制，不能确认 GPU 资源曾实际创建"); clean(); finish(false,"等待绘制超时"); }
		} else if (state == "等待延迟回收" && now-entered >= 800) {
			RequestQueue.sweepCache(); var released = true;
			for (bitmap in bitmaps) if (bitmap.data != null) released = false;
			if (!released) errors.push("延迟回收后仍有本次图片未释放");
			finish(!cancelled && errors.length == 0,cancelled ? "用户取消" : "完成");
		}
	}
	public function cancel():Void {
		cancelled = true;
		if (!loading && state != "等待延迟回收") { clean(); state = "等待延迟回收"; entered = MetricClock.now(); }
	}
	private function clean():Void {
		if (world != null) {
			var previous=world; world=null;
			try { previous.dispose(); } catch (error:Dynamic) { errors.push("场景释放失败："+Std.string(error)); }
		}
		if (assets != null) {
			var previous=assets; assets=null;
			try { previous.stop(); previous.clean(); } catch (error:Dynamic) { errors.push("资产释放失败："+Std.string(error)); }
		}
	}
	private function finish(passed:Bool,reason:String):Void {
		if (!busy) return;
		clean(); RequestQueue.RELEASE_DELAY = oldDelay; busy = false; state = reason;
		report = {complete:round == 20 && !cancelled,passed:passed && errors.length == 0,reason:reason,cycles:records,errors:errors,
			initial:initial,finalResources:RuntimeInfo.resources(),elapsedMs:MetricClock.now()-started,
			cachePolicy:{enabled:RequestQueue.enableCache,originalReleaseDelay:oldDelay,temporaryReleaseDelay:0.5},
			note:"引用、销毁标志与缓存图片释放检查，不证明浏览器 GC 或驱动显存立即回收"};
		bitmaps = []; done(report);
	}
}
