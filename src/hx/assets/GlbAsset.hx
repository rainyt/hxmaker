package hx.assets;

import haxe.io.Bytes;
import hx.formats.gltf.GlbImporter;
import hx.model.ModelAssetData;

/** GLB 兼容入口；实例化和共享数据管理统一由 ModelAsset 实现。 */
class GlbAsset extends ModelAsset {
	private function new(data:ModelAssetData) {
		super(data);
	}

	/** 同步解析并构建 GLB；图片仍须通过 Assets.loadGlb 解码后才能实例化。 */
	public static function fromBytes(bytes:Bytes):GlbAsset {
		return new GlbAsset(GlbImporter.importBytes(bytes));
	}
}
