package hx.assets;

import hx.display.Model3D;
import hx.display.Model3DOptions;
import hx.formats.gltf.GltfData;
import hx.formats.gltf.GlbParser;
import haxe.io.Bytes;

/** 可共享的 GLB 源资产；不持有场景节点、GPU 句柄或实例播放状态。 */
class GlbAsset {
	@:allow(hx.display.Model3D)
	private var data:GltfData;
	public var nodeCount(get, never):Int;
	public var meshCount(get, never):Int;
	public var triangleCount(get, never):Int;
	public var warnings(get, never):Array<String>;
	public var animationNames(get, never):Array<String>;
	private function new(data:GltfData) { this.data = data; }
	public static function fromBytes(bytes:Bytes):GlbAsset { return new GlbAsset(GlbParser.parse(bytes)); }
	public function createInstance(sceneIndex:Int = -1, options:Model3DOptions = null):Model3D { return new Model3D(this, sceneIndex, options); }
	private function get_nodeCount():Int { return data.nodes.length; }
	private function get_meshCount():Int { return data.meshes.length; }
	private function get_triangleCount():Int {
		var count = 0; for (mesh in data.meshes) for (primitive in mesh) count += Std.int(primitive.indices.length / 3); return count;
	}
	private function get_warnings():Array<String> { return data.warnings.copy(); }
	private function get_animationNames():Array<String> { return [for (clip in data.animations) clip.name]; }
}
