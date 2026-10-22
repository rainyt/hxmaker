package hx.assets;

import haxe.io.Bytes;
import hx.animation3d.AnimationClip3D;
import hx.animation3d.AnimationPose3D;
import hx.display.BitmapData;
import hx.display3d.Model3D;
import hx.display3d.Model3DOptions;
import hx.formats.ModelImporter;
import hx.model.ModelAssetData;
import hx.model.ModelAssetData.ModelBuildStats;
import hx.model.ModelAssetBuilder;
import hx.model.ModelSourceData;

/** 共享的模型资产；持有已构建数据和借用位图，不持有场景实例及 GPU 句柄。 */
class ModelAsset {
	@:allow(hx.display3d.Model3D)
	@:allow(hx.assets.ModelFuture)
	private var data:ModelAssetData;
	@:allow(hx.assets.ModelFuture)
	private var images:Array<BitmapData> = [];
	@:allow(hx.display3d.Model3D)
	private var clips:Array<AnimationClip3D>;
	@:allow(hx.display3d.Model3D)
	private var restPose:AnimationPose3D;

	/** 原导入格式标识：glb 或 fbx。 */
	public var sourceFormat(get, never):String;
	/** 中立数据语义版本，与未来的文件容器版本分离。 */
	public var dataVersion(get, never):Int;
	/** 资产预处理算法版本。 */
	public var buildVersion(get, never):Int;
	/** 资产内图片定义数。 */
	public var imageCount(get, never):Int;
	/** 纹理采样定义数，多个定义可以引用同一图片。 */
	public var textureCount(get, never):Int;
	/** 全部图片已经解码且未释放时为 true；没有图片也视为就绪。 */
	public var texturesReady(get, never):Bool;
	/** 全部源节点数，包含非当前实例场景的节点。 */
	public var nodeCount(get, never):Int;
	/** 源网格定义数。 */
	public var meshCount(get, never):Int;
	/** 源网格定义的三角形数，不按场景中的引用次数重复累计。 */
	public var triangleCount(get, never):Int;
	/** 返回构建统计副本，便于检查预处理结果；不代表实测性能。 */
	public var buildStats(get, never):ModelBuildStats;
	/** 导入及预处理提示的列表副本。 */
	public var warnings(get, never):Array<String>;
	/** 全部动画片段名称的列表副本。 */
	public var animationNames(get, never):Array<String>;

	private function new(data:ModelAssetData) {
		this.data = data;
		clips = [for (animation in data.animations) new AnimationClip3D(animation.name, animation.tracks)];
		restPose = new AnimationPose3D([for (node in data.nodes) node.translation], [for (node in data.nodes) node.rotation],
			[for (node in data.nodes) node.scale]);
	}

	/** 按文件内容同步导入模型；图片尚未解码时不可实例化，业务加载优先使用 Assets.loadModel。 */
	public static function fromBytes(bytes:Bytes):ModelAsset {
		return new ModelAsset(ModelImporter.importBytes(bytes));
	}

	/** 新导入器接入点；复制输入并校验、构建派生数据，不是发布文件的快速读取器。 */
	public static function fromSource(source:ModelSourceData):ModelAsset {
		return new ModelAsset(ModelAssetBuilder.build(source));
	}

	/** 创建独立姿态、几何和材质实例；贴图由加载资产的 Assets 持有。 */
	public function createInstance(sceneIndex:Int = -1, options:Model3DOptions = null):Model3D {
		return new Model3D(this, sceneIndex, options);
	}

	/** 返回共享位图，不转移所有权。 */
	public function getTexture(index:Int):BitmapData {
		if (index < 0 || index >= data.textures.length) throw "模型纹理索引越界";
		var image = images[data.textures[index].source];
		if (image == null || image.data == null) throw "模型图片尚未解码或已经释放，请通过 Assets 加载并保留资产";
		return image;
	}

	private function get_sourceFormat():String return data.sourceFormat;
	private function get_dataVersion():Int return data.dataVersion;
	private function get_buildVersion():Int return data.buildVersion;
	private function get_nodeCount():Int return data.nodes.length;
	private function get_imageCount():Int return data.images.length;
	private function get_textureCount():Int return data.textures.length;
	private function get_meshCount():Int return data.meshes.length;
	private function get_triangleCount():Int return data.stats.triangleCount;
	private function get_warnings():Array<String> return data.warnings.copy();
	private function get_animationNames():Array<String> return [for (clip in clips) clip.name];

	private function get_texturesReady():Bool {
		for (i in 0...data.images.length)
			if (images[i] == null || images[i].data == null) return false;
		return true;
	}

	private function get_buildStats():ModelBuildStats {
		var stats = data.stats;
		return {vertexCount: stats.vertexCount, triangleCount: stats.triangleCount, primitiveCount: stats.primitiveCount,
			generatedNormalCount: stats.generatedNormalCount, rigidPrimitiveCount: stats.rigidPrimitiveCount};
	}
}
