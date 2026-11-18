# Spine JSON 与二进制加载

`SpineTextureAtlasFuture` 在 `spine-haxe` 配置下同时准备 JSON 和二进制解析器。`createSkeletonData(value, scale = 1)` 按输入类型分流：`haxe.io.Bytes` 使用二进制解析，JSON 使用该运行库要求的文本输入。`scale` 在骨骼解析阶段应用。

以下片段可放入继承 `HxmakerAppliction` 的应用资源加载流程。示例保留图集引用，供显示对象销毁后释放：

```haxe
private var _spine:Spine;
private var _spineAtlas:AssetObject<SpineTextureAtlas>;

private function loadSpine():Void {
	new SpineTextureAtlasFuture({
		path:"assets/role/role",
		png:"assets/role/role.png",
		atlas:"assets/role/role.atlas"
	}).onComplete(function(atlas:AssetObject<SpineTextureAtlas>):Void {
		new BytesFuture("assets/role/role.skel.bytes")
			.onComplete(function(input:AssetObject<haxe.io.Bytes>):Void {
				var bytes:haxe.io.Bytes = input.data;
				input.release();
				try {
					var data:spine.SkeletonData = atlas.data.createSkeletonData(bytes, 0.01);
					_spine = new Spine(data);
					_spine.animationState.setAnimationByName(0, "idle", true);
					_spineAtlas = atlas;
					addChild(_spine);
				} catch (error:Dynamic) {
					atlas.release();
					trace("骨骼解析失败：" + Std.string(error));
				}
			}).onError(function(error:FutureErrorEvent):Void {
				atlas.release();
				trace(error.toString());
			});
	}).onError(function(error:FutureErrorEvent):Void {
		trace(error.toString());
	});
}
```

需要导入 `hx.display.Spine`、`hx.assets.AssetObject`、`hx.assets.BytesFuture`、`hx.assets.SpineTextureAtlas`、`hx.assets.SpineTextureAtlasFuture`、`hx.events.FutureErrorEvent`。JSON 使用 `StringFuture` 取得文本，再调用同一个 `createSkeletonData()`。骨骼解析后可释放输入字节或文本，图集与贴图仍须保留到所有使用它们的显示对象销毁。异步加载的调用方负责处理界面提前关闭的情况，避免迟到回调向已释放界面添加对象。

显示对象不再使用时先移除并 `dispose()`，随后 `_spineAtlas.release()`，清空对应字段。共享骨骼数据时应由统一资源库持有图集，实例各自管理动画状态。

## 分页图集

原有 `png`、`atlas`、`path` 参数保持可用。需要多页时额外传入 `pages:Map<String, String>`，键为 atlas 文本中的分页名，值为实际贴图路径；此时 `png` 可设为 `null`。每个区域从所属分页取得纹理，不再统一使用第一张图片。

可选 `atlasText:String` 用于已经读取的图集文本，传入后不重复读取 `atlas` 文件，后者可设为 `null`。组合多个 Unity AtlasAsset 时可使用此参数，调用方须消除分页命名冲突，并提供所有分页的贴图映射。图集缓存的 `path` 仍应是调用方统一管理的资产身份。

分页贴图加载失败或图集解析抛出异常时，通过 `onError` 回调结束并释放已取得的子资源；加载成功后的资源归返回的 `AssetObject` 所有，调用方须最终释放该对象。

## 兼容与验证范围

二进制能力依赖 `spine-haxe`。旧 `spine-hx` 配置保持 JSON 路径，传入 `Bytes` 时明确报错。本次未实测旧运行库与所有渲染后端。

在 MapEditor 的 Electron / OpenFL 构建中，已使用 `spine-haxe 4.2.9` 加载并绘制 4.2.36 的 JSON 和二进制样例，验证初始动画、顶点更新、分页纹理、旋转区域、缺页异常与引用计数释放。骨骼导出版本必须与运行库对应，通用引擎 API 本身不负责版本白名单；MapEditor 在调用前检查 4.2 文件头。
