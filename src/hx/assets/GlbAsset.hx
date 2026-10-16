package hx.assets;

import hx.display.Model3D;
import hx.display.Model3DOptions;
import hx.formats.gltf.GltfData;
import hx.formats.gltf.GlbParser;
import haxe.io.Bytes;
import hx.display.BitmapData;

/** 可共享的 GLB 源资产；不持有场景节点、GPU 句柄或实例播放状态。 */
class GlbAsset {
	@:allow(hx.display.Model3D)
	@:allow(hx.assets.GlbFuture)
	private var data:GltfData;
	@:allow(hx.assets.GlbFuture)
	private var images:Array<BitmapData> = [];

	/** 导入 GLB 的内嵌图片数。 */
	public var imageCount(get, never):Int;

	/** 导入 GLB 的纹理定义数，多个纹理可引用同一图片。 */
	public var textureCount(get, never):Int;

	/** 全部内嵌图片是否已解码且尚未释放。 */
	public var texturesReady(get, never):Bool;

	/** 源 GLB 节点总数，包含未被当前场景使用的节点。 */
	public var nodeCount(get, never):Int;

	/** 源 GLB 网格定义数。 */
	public var meshCount(get, never):Int;

	/** 源 GLB 全部网格定义的三角形数，不按节点实例次数重复累计。 */
	public var triangleCount(get, never):Int;

	/** 解析器兼容性提示的列表副本。 */
	public var warnings(get, never):Array<String>;

	/** 源动画片段名称的列表副本。 */
	public var animationNames(get, never):Array<String>;

	private function new(data:GltfData) {
		this.data = data;
	}

	/** 同步解析 GLB 结构；含图片时仍须通过 Assets.loadGlb 完成解码后才能创建实例。 */
	public static function fromBytes(bytes:Bytes):GlbAsset {
		return new GlbAsset(GlbParser.parse(bytes));
	}

	/** 创建独立姿态、网格与材质实例；-1 使用默认场景，贴图借用源 Assets 资源。 */
	public function createInstance(sceneIndex:Int = -1, options:Model3DOptions = null):Model3D {
		return new Model3D(this, sceneIndex, options);
	}

	private function get_nodeCount():Int {
		return data.nodes.length;
	}

	private function get_imageCount():Int {
		return data.images.length;
	}

	private function get_textureCount():Int {
		return data.textures.length;
	}

	private function get_texturesReady():Bool {
		for (i in 0...data.images.length)
			if (images[i] == null || images[i].data == null)
				return false;
		return true;
	}

	/** 返回共享位图，不转移所有权；图片仍由加载它的 Assets 持有。 */
	public function getTexture(index:Int):BitmapData {
		if (index < 0 || index >= data.textures.length)
			throw "GLB 纹理索引越界";
		var image = images[data.textures[index].source];
		if (image == null || image.data == null)
			throw "GLB 图片尚未解码或已经释放，请通过 Assets.loadGlb 加载并保留资产";
		return image;
	}

	private function get_meshCount():Int {
		return data.meshes.length;
	}

	private function get_triangleCount():Int {
		var count = 0;
		for (mesh in data.meshes)
			for (primitive in mesh)
				count += Std.int(primitive.indices.length / 3);
		return count;
	}

	private function get_warnings():Array<String> {
		return data.warnings.copy();
	}

	private function get_animationNames():Array<String> {
		return [for (clip in data.animations) clip.name];
	}
}
