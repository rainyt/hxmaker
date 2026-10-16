package hx.assets;

import hx.events.FutureErrorEvent;

/** 只通过引擎的二进制加载队列请求文件，解析完成后才完成外层 Future。 */
class GlbFuture extends Future<GlbAsset, String> {
	private var pending:Bool = false;
	override public function post():Void {
		if (pending || isComplete) return;
		pending = true; isError = false; error = null;
		var bytes = new BytesFuture(getLoadData(), false);
		bytes.onComplete(object -> {
			var asset:GlbAsset;
			try { asset = GlbAsset.fromBytes(object.data); }
			catch (error:Dynamic) {
				object.release(); pending = false;
				var event = FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "GLB 解析失败：" + Std.string(error));
				event.path = path; errorValue(event); return;
			}
			addAssetObject(object); pending = false;
			// 二进制缓存由子 AssetObject 持有，外层模型不重复占用同一 URL 的引用。
			completeValue(asset);
		});
		bytes.onError(error -> {
			pending = false;
			var event = FutureErrorEvent.create(error.type, error.errorCode, error.error); event.path = path; errorValue(event);
		});
		bytes.onProgress(progressValue); bytes.post();
	}
}
