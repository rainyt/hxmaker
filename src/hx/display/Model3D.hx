package hx.display;

import hx.assets.GlbAsset;
import hx.animation3d.AnimationClip3D;
import hx.animation3d.AnimationPlayer3D;
import hx.animation3d.Skin3D;
import hx.formats.gltf.GltfData;
import hx.geom.Matrix3D;
import hx.geom.Bounds3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.material.UnlitTextureMaterial;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.render3d.Math3D;

/** GLB 的独立实例；拥有运行时几何和材质，不拥有共享源资产。 */
class Model3D extends Node3D {
	public var animation(default, null):AnimationPlayer3D;
	public var meshes(get, never):Array<MeshObject>;
	public var triangleCount(default, null):Int = 0;
	private var data:GltfData;
	private var nodes:Array<Node3D> = [];
	private var active:Array<Bool>;
	private var globals:Array<Matrix3D>;
	private var translations:Array<Array<Float>>;
	private var rotations:Array<Array<Float>>;
	private var scales:Array<Array<Float>>;
	private var skins:Map<Int, Skin3D> = [];
	private var instances:Array<MeshObject> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Map<Int, Material3D> = [];
	private var previousClip:AnimationClip3D;
	private function get_meshes():Array<MeshObject> { return instances.copy(); }
	public function new(asset:GlbAsset, sceneIndex:Int = -1) {
		super();
		if (asset == null) throw "模型源资产不能为空";
		data = asset.data;
		if (sceneIndex < 0) sceneIndex = data.scene;
		if (sceneIndex >= data.scenes.length) throw "模型场景索引越界";
		active = [for (_ in data.nodes) false]; globals = [for (_ in data.nodes) new Matrix3D()];
		translations = [for (node in data.nodes) node.translation.copy()];
		rotations = [for (node in data.nodes) node.rotation.copy()]; scales = [for (node in data.nodes) node.scale.copy()];
		try {
			for (source in data.nodes) { var node = new Node3D(); node.name = source.name; nodes.push(node); }
			for (i in 0...nodes.length) for (child in data.nodes[i].children) nodes[i].addChild(nodes[child]);
			function activate(index:Int):Void { active[index] = true; for (child in data.nodes[index].children) activate(child); }
			for (index in data.scenes[sceneIndex]) { addChild(nodes[index]); activate(index); }
			for (i in 0...nodes.length) if (active[i] && data.nodes[i].mesh >= 0) createMeshes(i);
			animation = new AnimationPlayer3D(data.animations, (clip, time) -> applyPose(clip, time)); applyPose(null, 0, true);
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	private function createMeshes(index:Int):Void {
		var node = data.nodes[index], primitives = data.meshes[node.mesh];
		var skin:Skin3D = null;
		if (node.skin >= 0) {
			skin = skins.get(node.skin);
			if (skin == null) {
				for (joint in data.skins[node.skin].joints) if (!active[joint]) throw "蒙皮关节不属于所选场景";
				skin = new Skin3D(data.skins[node.skin]); skins.set(node.skin, skin);
			}
		}
		for (i in 0...primitives.length) {
			var primitive = primitives[i], material = materials.get(primitive.material);
			if (material == null) {
				material = new UnlitTextureMaterial();
				if (primitive.material >= 0) {
					var source = data.materials[primitive.material];
					material.color = source.color; material.opacity = source.opacity;
					material.alphaMode = switch (source.alphaMode) { case "MASK": AlphaMode3D.MASK; case "BLEND": AlphaMode3D.BLEND; default: AlphaMode3D.OPAQUE; };
					material.alphaCutoff = source.alphaCutoff; material.cullMode = source.doubleSided ? CullMode3D.NONE : CullMode3D.BACK;
				}
				materials.set(primitive.material, material);
			}
			var geometry = new Geometry3D(primitive.positions, primitive.uvs, primitive.indices); geometries.push(geometry);
			var mesh = new MeshObject(geometry, material); mesh.name = node.name + (primitives.length > 1 ? " / " + i : "");
			instances.push(mesh); triangleCount += Std.int(primitive.indices.length / 3);
			if (skin == null) nodes[index].addChild(mesh);
			else {
				// glTF 蒙皮忽略网格节点自身及其父级变换，关节全局矩阵已包含骨架层级。
				addChild(mesh); skin.bind(mesh, primitive);
			}
		}
	}
	/** 显式驱动动画；暂停时不重复计算蒙皮，静态模型只在创建时计算初始姿态。 */
	public function update(dt:Float):Void { if (!isDisposed) animation.update(dt); }
	private function applyPose(clip:AnimationClip3D, time:Float, force:Bool = false):Void {
		if (isDisposed) return;
		var reset = force || previousClip != clip, changed = [for (_ in data.nodes) reset];
		if (reset) for (i in 0...data.nodes.length) {
			for (j in 0...3) { translations[i][j] = data.nodes[i].translation[j]; scales[i][j] = data.nodes[i].scale[j]; }
			for (j in 0...4) rotations[i][j] = data.nodes[i].rotation[j];
		}
		if (clip != null) for (track in clip.tracks) {
			var output = switch (track.path) { case "translation": translations[track.node]; case "rotation": rotations[track.node]; default: scales[track.node]; };
			AnimationClip3D.sample(track, time, output); changed[track.node] = true;
		}
		for (i in 0...nodes.length) if (changed[i]) {
			var source = data.nodes[i];
			nodes[i].setLocalMatrix(source.matrix != null ? new Matrix3D(source.matrix) : Math3D.fromTRS(translations[i], rotations[i], scales[i]));
		}
		var resolved = [for (_ in nodes) false];
		function resolve(index:Int):Void {
			if (resolved[index]) return;
			var parent = data.parents[index], local = nodes[index].getLocalMatrix();
			if (parent >= 0) { resolve(parent); globals[index] = Math3D.multiply(globals[parent], local); } else globals[index] = local;
			resolved[index] = true;
		}
		// 在模型空间解析骨架祖先，不重复应用外层模型的世界变换。
		for (i in 0...nodes.length) if (active[i]) resolve(i);
		for (skin in skins) skin.update(globals);
		previousClip = clip;
	}
	/** 返回模型局部包围盒，可通过过滤函数排除资产附带的展示地面。 */
	public function getBounds(include:MeshObject->Bool = null):Bounds3D {
		var result = new Bounds3D();
		for (mesh in instances) if (!mesh.isDisposed && mesh.geometry != null && (include == null || include(mesh))) {
			var transform = mesh.getLocalMatrix(), parent = mesh.parent;
			while (parent != null && parent != this) { transform = Math3D.multiply(parent.getLocalMatrix(), transform); parent = parent.parent; }
			var bounds = mesh.geometry.bounds.transformed(transform);
			if (!bounds.isEmpty()) { result.include(bounds.min.x, bounds.min.y, bounds.min.z); result.include(bounds.max.x, bounds.max.y, bounds.max.z); }
		}
		return result;
	}
	override public function dispose():Void {
		if (isDisposed) return;
		if (animation != null) animation.dispose();
		super.dispose();
		for (mesh in instances) if (!mesh.isDisposed) mesh.dispose();
		for (node in nodes) if (!node.isDisposed) node.dispose();
		for (geometry in geometries) geometry.dispose();
		for (material in materials) material.dispose();
		for (skin in skins) skin.dispose();
		nodes = []; instances = []; geometries = []; materials.clear(); skins.clear();
		translations = []; rotations = []; scales = []; globals = []; active = []; data = null; previousClip = null;
	}
}
