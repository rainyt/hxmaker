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
	public var imageCount(get, never):Int;
	public var textureCount(get, never):Int;
	public var texturesReady(get, never):Bool;
	public var nodeCount(get, never):Int;
	public var meshCount(get, never):Int;
	public var triangleCount(get, never):Int;
	public var warnings(get, never):Array<String>;
	public var animationNames(get, never):Array<String>;
	private function new(data:GltfData) { this.data = data; }
	public static function fromBytes(bytes:Bytes):GlbAsset { return new GlbAsset(GlbParser.parse(bytes)); }
	public function createInstance(sceneIndex:Int = -1, options:Model3DOptions = null):Model3D { return new Model3D(this, sceneIndex, options); }
	private function get_nodeCount():Int { return data.nodes.length; }
	private function get_imageCount():Int { return data.images.length; }
	private function get_textureCount():Int { return data.textures.length; }
	private function get_texturesReady():Bool {
		for (i in 0...data.images.length) if (images[i] == null || images[i].data == null) return false;
		return true;
	}
	/** 返回共享位图，不转移所有权；图片仍由加载它的 Assets 持有。 */
	public function getTexture(index:Int):BitmapData {
		if (index < 0 || index >= data.textures.length) throw "GLB 纹理索引越界";
		var image = images[data.textures[index].source];
		if (image == null || image.data == null) throw "GLB 图片尚未解码或已经释放，请通过 Assets.loadGlb 加载并保留资产";
		return image;
	}
	private function get_meshCount():Int { return data.meshes.length; }
	private function get_triangleCount():Int {
		var count = 0; for (mesh in data.meshes) for (primitive in mesh) count += Std.int(primitive.indices.length / 3); return count;
	}
	private function get_warnings():Array<String> { return data.warnings.copy(); }
	private function get_animationNames():Array<String> { return [for (clip in data.animations) clip.name]; }
}
