package hx.formats.gltf;

import haxe.io.Bytes;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.model.ModelAssetBuilder;
import hx.model.ModelAssetData;
import hx.model.ModelSourceData;

/** GLB 语义只在导入边界解释；运行时不再依赖 glTF 类型或枚举字符串。 */
class GlbImporter {
	/** 解析并构建中立资产；图片字节保留，解码仍通过 Assets 的 Future 完成。 */
	public static function importBytes(bytes:Bytes):ModelAssetData {
		var gltf = GlbParser.parse(bytes);
		var source:ModelSourceData = {
			sourceFormat: "glb",
			nodes: gltf.nodes,
			scenes: gltf.scenes,
			scene: gltf.scene,
			meshes: gltf.meshes,
			materials: [for (material in gltf.materials) {
				name: material.name,
				baseColorFactor: material.baseColorFactor,
				metallicFactor: material.metallicFactor,
				roughnessFactor: material.roughnessFactor,
				emissiveFactor: material.emissiveFactor,
				color: material.color,
				opacity: material.opacity,
				alphaMode: switch (material.alphaMode) {
					case "MASK": AlphaMode3D.MASK;
					case "BLEND": AlphaMode3D.BLEND;
					default: AlphaMode3D.OPAQUE;
				},
				alphaCutoff: material.alphaCutoff,
				cullMode: material.doubleSided ? CullMode3D.NONE : CullMode3D.BACK,
				baseColorTexture: material.baseColorTexture
			}],
			images: gltf.images,
			textures: [for (texture in gltf.textures) {
				source: texture.source,
				wrapU: texture.wrapU,
				wrapV: texture.wrapV,
				smoothing: texture.smoothing,
				minSmoothing: texture.minSmoothing
			}],
			skins: gltf.skins,
			animations: [for (clip in gltf.animations) {name: clip.name, tracks: clip.tracks}],
			warnings: gltf.warnings
		};
		return ModelAssetBuilder.build(source);
	}
}
