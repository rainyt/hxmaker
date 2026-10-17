package hx.assets;

/** 统一模型加载入口；首版只导入 GLB，按文件内容校验，不依赖 URL 后缀。 */
class ModelFuture extends ModelAssetFuture<ModelAsset> {
	public function new(path:String, autoPost:Bool = true) {
		super(path, autoPost, ModelAsset.fromGlb);
	}
}
