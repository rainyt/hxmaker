package hx.assets;

/** 保留 Future<GlbAsset, String> 类型契约，复用统一的模型加载与失败清理流程。 */
class GlbFuture extends ModelAssetFuture<GlbAsset> {
	public function new(path:String = null, autoPost:Bool = true) {
		super(path, autoPost, GlbAsset.fromBytes);
	}
}
