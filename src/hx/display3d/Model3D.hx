package hx.display3d;

import hx.assets.ModelAsset;
import hx.animation3d.AnimationClip3D;
import hx.animation3d.AnimationPlayer3D;
import hx.animation3d.AnimationPose3D;
import hx.animation3d.Skin3D;
import hx.model.ModelAssetData;
import hx.geom.Matrix3D;
import hx.geom.Bounds3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.material.UnlitTextureMaterial;
import hx.material.LambertTextureMaterial;
import hx.material.PbrMaterial3D;
import hx.render3d.Math3D;

/** 模型资产的独立实例；拥有运行时几何和材质，不拥有共享源资产。 */
class Model3D extends Node3D {
	/** 模型实例独立的播放器，由业务每帧显式推进一次。 */
	public var animation(default, null):AnimationPlayer3D;

	/** 活动导入场景的网格列表副本，网格引用由模型拥有。 */
	public var meshes(get, never):Array<MeshObject>;

	/** 当前实例活动场景的导入三角形总数。 */
	public var triangleCount(default, null):Int = 0;

	private var data:ModelAssetData;
	private var nodes:Array<Node3D> = [];
	private var active:Array<Bool>;
	private var globals:Array<Matrix3D>;
	private var restPose:AnimationPose3D;
	private var pose:AnimationPose3D;
	private var appliedPose:AnimationPose3D;
	private var sourcePose:AnimationPose3D;
	private var targetPose:AnimationPose3D;
	private var snapshotPose:AnimationPose3D;
	private var poseReady:Bool = false;
	private var activeNodes:Array<Int>;
	private var skins:Map<Int, Skin3D> = [];
	private var instances:Array<MeshObject> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Map<Int, Material3D> = [];
	private var useLighting:Bool;
	private var usePbr:Bool;
	private var sourceAsset:ModelAsset;

	private function get_meshes():Array<MeshObject> {
		return instances.copy();
	}

	/** 从已加载的模型资产创建独立模型实例；-1 使用默认场景，源贴图仍由 Assets 持有。 */
	public function new(asset:ModelAsset, sceneIndex:Int = -1, options:Model3DOptions = null) {
		super();
		if (asset == null)
			throw "模型源资产不能为空";
		if (!asset.texturesReady)
			throw "模型图片尚未解码或已经释放，请通过 Assets 加载并保留资产";
		sourceAsset = asset;
		data = asset.data;
		useLighting = options != null && options.lightingEnabled == true;
		usePbr = options != null && options.pbrEnabled == true;
		if (sceneIndex < 0)
			sceneIndex = data.scene;
		if (sceneIndex < 0 || sceneIndex >= data.scenes.length)
			throw "模型场景索引越界";
		active = [for (_ in data.nodes) false];
		activeNodes = data.sceneNodes[sceneIndex];
		for (index in activeNodes)
			active[index] = true;
		// 第一次应用姿态时按父节点优先顺序填充，避免先分配马上被替换的单位矩阵。
		globals = [for (_ in data.nodes) null];
		restPose = asset.restPose;
		pose = restPose.clone();
		appliedPose = restPose.clone();
		try {
			for (source in data.nodes) {
				var node = new Node3D();
				node.name = source.name;
				nodes.push(node);
			}
			for (i in 0...nodes.length)
				for (child in data.nodes[i].children)
					nodes[i].addChild(nodes[child]);
			for (index in data.scenes[sceneIndex])
				addChild(nodes[index]);
			for (i in 0...nodes.length)
				if (active[i] && data.nodes[i].mesh >= 0)
					createMeshes(i);
			animation = new AnimationPlayer3D(asset.clips, applyPose, {capture: capturePose, apply: applyBlend});
			applyPose(null, 0);
		} catch (error:Dynamic) {
			dispose();
			throw error;
		}
	}

	private function createMeshes(index:Int):Void {
		var node = data.nodes[index], primitives = data.meshes[node.mesh];
		var skin:Skin3D = null;
		if (node.skin >= 0) {
			skin = skins.get(node.skin);
			if (skin == null) {
				for (joint in data.skins[node.skin].joints)
					if (!active[joint])
						throw "蒙皮关节不属于所选场景";
				skin = new Skin3D(data.skins[node.skin]);
				skins.set(node.skin, skin);
			}
		}
		for (i in 0...primitives.length) {
			var primitive = primitives[i],
				material = materials.get(primitive.material);
			if (material == null) {
				material = usePbr ? new PbrMaterial3D(null, 0xffffff, data.sourceFormat == "glb" ? 1 : 0, 1) : useLighting ? new LambertTextureMaterial() : new UnlitTextureMaterial();
				material.colorMultiplyLinear = true;
				if (primitive.material >= 0) {
					var source = data.materials[primitive.material];
					material.color = source.color;
					if (usePbr) {
						var pbr:PbrMaterial3D = cast material;
						// 保留源线性因子的精度，避免经过 RGB 整数量化再还原。
						pbr.color = 0xffffff;
						pbr.baseColorFactor = source.baseColorFactor.slice(0, 3);
						pbr.metallic = source.metallicFactor;
						pbr.roughness = source.roughnessFactor;
						pbr.emissive = source.emissiveFactor;
					}
					material.opacity = source.opacity;
					if (source.baseColorTexture >= 0) {
						var texture = data.textures[source.baseColorTexture];
						material.texture = sourceAsset.getTexture(source.baseColorTexture);
						material.smoothing = texture.smoothing;
						material.textureMinSmoothing = texture.minSmoothing;
						material.textureWrapU = texture.wrapU;
						material.textureWrapV = texture.wrapV;
					}
					material.alphaMode = source.alphaMode;
					material.alphaCutoff = source.alphaCutoff;
					material.cullMode = source.cullMode;
				}
				materials.set(primitive.material, material);
			}
			var geometry = Geometry3D.fromModelPrimitive(primitive, skin != null);
			geometries.push(geometry);
			var mesh = new MeshObject(geometry, material);
			mesh.name = node.name + (primitives.length > 1 ? " / " + i : "");
			instances.push(mesh);
			triangleCount += primitive.triangleCount;
			if (skin == null)
				nodes[index].addChild(mesh);
			else {
				// 资产已统一绑定空间；关节模型空间矩阵包含骨架层级，不重复应用网格节点变换。
				addChild(mesh);
				skin.bind(mesh, primitive);
			}
		}
	}

	/** 显式驱动动画；暂停时不重复计算蒙皮，静态模型只在创建时计算初始姿态。 */
	public function update(dt:Float):Void {
		if (!isDisposed)
			animation.update(dt);
	}

	/** 返回当前场景的导入节点；越界、未激活或已销毁时返回 null。引用由模型所有。 */
	public function getNodeByIndex(index:Int):Node3D {
		if (isDisposed || index < 0 || index >= nodes.length || !active[index] || nodes[index].isDisposed)
			return null;
		return nodes[index];
	}

	/** 重名节点全部返回，顺序按源节点索引；不包含运行时创建的挂点。 */
	public function findNodes(name:String):Array<Node3D> {
		var result:Array<Node3D> = [];
		if (!isDisposed)
			for (i in 0...nodes.length) {
				var node = getNodeByIndex(i);
				if (node != null && node.name == name)
					result.push(node);
			}
		return result;
	}

	/** 将借用节点映射回源节点索引；外部节点、挂点和非活动节点返回 -1。 */
	public function getNodeIndex(node:Node3D):Int {
		if (isDisposed || node == null)
			return -1;
		var index = nodes.indexOf(node);
		return getNodeByIndex(index) == null ? -1 : index;
	}

	/** 挂点偏移不受动画覆盖；模型销毁时一起销毁，需保留的附件请先移出。 */
	public function createSocket(nodeIndex:Int, name:String = null):Node3D {
		var target = getNodeByIndex(nodeIndex);
		if (target == null)
			throw "挂点目标必须是当前模型场景内的有效节点";
		var socket = new Node3D();
		socket.name = name;
		target.addChild(socket);
		return socket;
	}

	private function capturePose():Void {
		if (snapshotPose == null)
			snapshotPose = pose.clone();
		else
			snapshotPose.copyFrom(pose);
	}

	private function applyPose(clip:AnimationClip3D, time:Float):Void {
		if (isDisposed)
			return;
		pose.sample(restPose, clip, time);
		commitPose();
	}

	private function applyBlend(source:AnimationClip3D, sourceTime:Float, target:AnimationClip3D, targetTime:Float, weight:Float):Void {
		if (isDisposed)
			return;
		// 过渡缓冲按需建立，普通单片段播放不额外采样。
		if (sourcePose == null) {
			sourcePose = restPose.clone();
			targetPose = restPose.clone();
		}
		if (source != null)
			sourcePose.sample(restPose, source, sourceTime);
		targetPose.sample(restPose, target, targetTime);
		pose.blend(source == null ? snapshotPose : sourcePose, targetPose, weight);
		commitPose();
	}

	private function commitPose():Void {
		var changed = !poseReady;
		for (i in activeNodes) {
			var nodeChanged = !poseReady;
			if (!nodeChanged) {
				for (j in 0...3)
					if (pose.translations[i][j] != appliedPose.translations[i][j] || pose.scales[i][j] != appliedPose.scales[i][j])
						nodeChanged = true;
				for (j in 0...4)
					if (pose.rotations[i][j] != appliedPose.rotations[i][j])
						nodeChanged = true;
			}
			if (nodeChanged) {
				var source = data.nodes[i];
				if (source.matrix != null)
					nodes[i].setLocalMatrix(new Matrix3D(source.matrix));
				else
					nodes[i].setAnimationTRS(pose.translations[i], pose.rotations[i], pose.scales[i]);
				changed = true;
			}
		}
		if (!changed)
			return;
		appliedPose.copyFrom(pose);
		poseReady = true;
		// 资产已预计算父节点优先顺序，姿态更新不再递归寻找祖先。
		for (index in activeNodes) {
			var parent = data.parents[index],
				local = nodes[index].getLocalMatrix();
			globals[index] = parent >= 0 ? Math3D.multiply(globals[parent], local) : local;
		}
		for (skin in skins)
			skin.update(globals);
	}

	/** 返回模型局部包围盒，可通过过滤函数排除资产附带的展示地面。 */
	public function getBounds(include:MeshObject->Bool = null):Bounds3D {
		var result = new Bounds3D();
		for (mesh in instances)
			if (!mesh.isDisposed && mesh.geometry != null && (include == null || include(mesh))) {
				var transform = mesh.getLocalMatrix(), parent = mesh.parent;
				while (parent != null && parent != this) {
					transform = Math3D.multiply(parent.getLocalMatrix(), transform);
					parent = parent.parent;
				}
				var bounds = mesh.geometry.bounds.transformed(transform);
				if (!bounds.isEmpty()) {
					result.include(bounds.min.x, bounds.min.y, bounds.min.z);
					result.include(bounds.max.x, bounds.max.y, bounds.max.z);
				}
			}
		return result;
	}

	/** 幂等销毁实例动画、蒙皮、节点及自有几何材质，不销毁 Assets 源贴图。 */
	override public function dispose():Void {
		if (isDisposed)
			return;
		if (animation != null)
			animation.dispose();
		super.dispose();
		for (mesh in instances)
			if (!mesh.isDisposed)
				mesh.dispose();
		for (node in nodes)
			if (!node.isDisposed)
				node.dispose();
		for (geometry in geometries)
			geometry.dispose();
		for (material in materials)
			material.dispose();
		for (skin in skins)
			skin.dispose();
		nodes = [];
		instances = [];
		geometries = [];
		materials.clear();
		skins.clear();
		restPose = pose = appliedPose = sourcePose = targetPose = snapshotPose = null;
		globals = [];
		active = [];
		activeNodes = [];
		data = null;
		sourceAsset = null;
	}
}
