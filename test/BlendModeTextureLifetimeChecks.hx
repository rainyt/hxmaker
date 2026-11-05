package;

import hx.core.Engine;
import hx.core.Hxmaker;
import hx.core.IEngine;
import hx.core.OpenFlBitmapData;
import hx.core.Render;
import hx.display.IBitmapData;
import hx.display.BitmapData;
import hx.filters.StageBitmapData;
import hx.render.ImageBufferData;
import hx.render2d.openfl.DirectBatchDisplay;
import hx.render2d.openfl.DirectBatchRenderer;
import hx.render2d.openfl.TextureLifetime;
import hx.shader.MultiTextureShader;
import hx.net.RequestQueue;
import openfl.display.ShaderInput;

/** 在浏览器执行真实资源协议检查，使用公开池接口，不依赖旧的帧索引实现。 */
@:access(hx.core.Engine)
@:access(hx.core.Hxmaker)
@:access(hx.core.Render)
@:access(hx.net.RequestQueue)
@:access(openfl.display.BitmapData)
class BlendModeTextureLifetimeChecks {
	private static function check(value:Bool, message:String):Void { if (!value) throw message; }
	/** 构造不上传 GPU 的有效原生位图，销毁仍使用真实 BitmapData.dispose。 */
	private static function bitmap():openfl.display.BitmapData {
		var result:openfl.display.BitmapData = new openfl.display.BitmapData(16, 16, true, 0);
		return result;
	}
	/** 根与切片拥有明确所有权，两个公开视图释放后才销毁。 */
	private static function checkViews():Void {
		var raw:openfl.display.BitmapData = bitmap();
		var root:BitmapData = OpenFlBitmapData.fromBitmapData(raw);
		var child:BitmapData = root.sub(0, 0, 4, 4);
		root.dispose(); check(raw.width == 16 && child.data != null, "释放根视图不能误删子视图的纹理");
		child.dispose(); child.dispose(); check(raw.width == 0, "最后一个视图退出后应最终释放");
		var shared:openfl.display.BitmapData = bitmap();
		var a:BitmapData = OpenFlBitmapData.fromBitmapData(shared); var b:BitmapData = OpenFlBitmapData.fromBitmapData(shared);
		var alias:BitmapData = BitmapData.formData(a.data);
		a.dispose(); alias.dispose(); check(shared.width == 16, "同原生根的两个包装器应共享释放权");
		b.dispose(); check(shared.width == 0, "最后一个后端所有者退出后才物理释放");
	}
	/** 快照持续持有；池归还和帧索引重置不能允许反馈覆盖。 */
	private static function checkPool():Void {
		var previous:IEngine = Hxmaker.engine;
		var engine:Engine = Type.createEmptyInstance(Engine);
		engine.____stageWidth = 16; engine.____stageHeight = 16; engine.contextGeneration = 0;
		Hxmaker.__engine = engine;
		var a:StageBitmapData = new StageBitmapData(); a.clear();
		var raw:openfl.display.BitmapData = a.data.getTexture();
		var batch:DirectBatchDisplay = new DirectBatchDisplay(new DirectBatchRenderer()); batch.addTexture(raw);
		a.dispose(); StageBitmapData.resetPool();
		var b:StageBitmapData = new StageBitmapData(); b.clear();
		check(b.data.getTexture() != raw, "池不能覆盖仍被静止快照读取的目标");
		StageBitmapData.update(10); check(raw.width == 16, "闲置维护不能销毁读取中的目标");
		b.dispose(); batch.retire(); batch.retire(); batch.dispose();
		StageBitmapData.disposeAll(); check(raw.width == 0 && StageBitmapData.counts == 0, "全部借用和读取退出后可以回收");
		Hxmaker.__engine = previous;
	}
	/** 显式自动槽清尾，材质专用输入保持原值。 */
	private static function checkSlots():Void {
		var current:openfl.display.BitmapData = bitmap(); var stale:openfl.display.BitmapData = bitmap();
		var mask:openfl.display.BitmapData = bitmap();
		var shader:MultiTextureShader = Type.createEmptyInstance(MultiTextureShader);
		var inputs:Array<ShaderInput<openfl.display.BitmapData>> = [];
		for (index in 0...3) { var input:ShaderInput<openfl.display.BitmapData> = new ShaderInput(); input.input = stale; inputs.push(input); }
		shader.data = cast {uSampler0:inputs[0], uSampler1:inputs[1], uSampler2:inputs[2]};
		shader.batchTextureSlots = ["uSampler0", "uSampler1", "uSampler2"];
		var render:Render = Type.createEmptyInstance(Render); render.currentShader = shader;
		var data:ImageBufferData = new ImageBufferData(); data.bitmapDatas = [current];
		render.setBatchTextures(data, false);
		for (input in inputs) check(input.input == current, "纯多纹理自定义 Shader 必须覆盖全部管理槽");
		shader.batchTextureSlots = ["uSampler0"]; inputs[1].input = mask;
		render.setBatchTextures(data, false); check(inputs[1].input == mask, "材质槽不能被自动合批覆盖");
		current.dispose(); stale.dispose(); mask.dispose();
	}
	/** 缓存零业务计数仍须等待快照退役，重复 release 不能下溢。 */
	private static function checkCache():Void {
		var key:String = "__render_lifetime_check__";
		var entry:Dynamic = RequestQueue.ensureCacheEntry(key, function(data:Dynamic, error:Dynamic):Void {});
		var raw:openfl.display.BitmapData = bitmap(); var data:BitmapData = OpenFlBitmapData.fromBitmapData(raw);
		RequestQueue.resolveCacheEntry(key, entry, data, null);
		RequestQueue.retain(key); RequestQueue.release(key); RequestQueue.release(key);
		check(RequestQueue.getRefCount(key) == 0, "重复 release 不能产生负引用");
		var batch:DirectBatchDisplay = new DirectBatchDisplay(new DirectBatchRenderer()); batch.addTexture(raw);
		RequestQueue.collectUnused(64, 100, 8388608); check(raw.width == 16 && RequestQueue.hasCache(key), "旧快照持有的缓存不得提前清理");
		batch.retire(); batch.dispose(); RequestQueue.collectUnused(64, 100, 8388608);
		check(raw.width == 0 && !RequestQueue.hasCache(key), "快照退役后无需新请求即可回收缓存");
	}
	/** 强制撤销后的旧完成结果和旧代号不能误改同 URL 的新条目。 */
	private static function checkCacheGeneration():Void {
		var key:String = "__render_generation_check__";
		var old:Dynamic = RequestQueue.ensureCacheEntry(key, function(data:Dynamic, error:Dynamic):Void {});
		var oldId:Int = RequestQueue.getEntryId(key); RequestQueue.removeCache(key);
		var current:Dynamic = RequestQueue.ensureCacheEntry(key, function(data:Dynamic, error:Dynamic):Void {});
		var raw:openfl.display.BitmapData = bitmap();
		check(!RequestQueue.resolveCacheEntry(key, old, OpenFlBitmapData.fromBitmapData(raw), null) && raw.width == 0,
			"撤销后的异步结果必须释放并拒绝接收");
		check(RequestQueue.retain(key, oldId) == 0 && RequestQueue.getRefCount(key) == 0, "旧代号不能增加新条目计数");
		check(RequestQueue.getEntryId(key) != oldId, "相同 URL 的新请求必须获得新代号");
		RequestQueue.removeCache(key);
	}
	/** 等待回调重入清理、重发时，也不能删除或保留错误的缓存代次。 */
	private static function checkReentrantCache():Void {
		for (failed in [false, true]) {
			var key:String = "__reentrant_cache__";
			var entry:Dynamic = RequestQueue.ensureCacheEntry(key, function(data:Dynamic, error:Dynamic):Void {});
			var replacementId:Int = 0;
			RequestQueue.ensureCacheEntry(key, function(data:Dynamic, error:Dynamic):Void {
				RequestQueue.removeCache(key);
				RequestQueue.ensureCacheEntry(key, function(value:Dynamic, failure:Dynamic):Void {});
				replacementId = RequestQueue.getEntryId(key);
			});
			var raw:openfl.display.BitmapData = failed ? null : bitmap();
			var error:hx.events.FutureErrorEvent = failed ? hx.events.FutureErrorEvent.create(hx.events.FutureErrorEvent.LOAD_ERROR, -1, "注入加载失败") : null;
			var accepted:Bool = RequestQueue.resolveCacheEntry(key, entry, raw == null ? null : OpenFlBitmapData.fromBitmapData(raw), error);
			check(replacementId > 0 && RequestQueue.getEntryId(key) == replacementId, "回调重入不能删除同 URL 的新条目");
			if (!failed) check(!accepted && raw.width == 0, "首个成功回调不能接收已经被等待者撤销的结果");
			RequestQueue.removeCache(key);
		}
	}

	/** 共享 Assets 最后一个持有者退出才释放图集切片；清理后的异步完成不得复活宿主。 */
	private static function checkAssets():Void {
		var raw:openfl.display.BitmapData = bitmap(); var root:BitmapData = OpenFlBitmapData.fromBitmapData(raw);
		var atlas:hx.assets.Atlas = new hx.assets.Atlas(root);
		var view:BitmapData = root.sub(0, 0, 4, 4); atlas.bitmapDatas.set("view", view);
		var tracked:hx.assets.AssetObject<Dynamic> = new hx.assets.AssetObject(null, atlas); tracked.retain();
		var first:hx.assets.Assets = new hx.assets.Assets(); first.assetObjects.push(tracked);
		var second:hx.assets.Assets = new hx.assets.Assets(); second.pushAssets(first);
		first.clean(); check(view.data != null, "一个 Assets 清理不能释放另一个 Assets 的图集");
		second.clean(); check(view.data == null, "最后一个 Assets 清理后退出图集视图所有权"); root.dispose();
		check(raw.width == 0, "图集视图退出后根纹理可最终释放");
		var host:hx.assets.Assets = new hx.assets.Assets();
		var future:hx.assets.Future<Dynamic, String> = new hx.assets.Future("__late_result__", false);
		host.pushFuture(future); host.clean(); future.completeValue("late");
		check(host.assetObjects.length == 0 && !host.strings.keys().hasNext(), "宿主清理后异步结果不得复活资源表");
	}
	/** 非法、空及超预算目标在分配前拒绝，小数边界采用向上取整。 */
	private static function checkBounds():Void {
		for (width in [0., -1., Math.NaN, Math.POSITIVE_INFINITY, 1e9]) {
			var rejected:Bool = false;
			try { hx.render2d.openfl.RenderTargetBudget.validate(width, 16); }
			catch (error:hx.render2d.openfl.TextureInputError) { rejected = error.kind == InvalidSize; }
			check(rejected, "非法边界必须分类拒绝");
		}
		var filter:hx.filters.DisplayObjectFilter = new hx.filters.DisplayObjectFilter();
		var value:BitmapData = filter.createCacheBitmapData(1.2, 2.2);
		check(value.width == 2 && value.height == 3, "小数边界不能向下取整截断像素"); value.dispose(); filter.dispose();
	}

	private static function main():Void {
		checkViews(); checkPool(); checkSlots(); checkCache(); checkCacheGeneration(); checkReentrantCache(); checkAssets(); checkBounds();
		trace("混合模式纹理生命周期检查完成");
	}
}
