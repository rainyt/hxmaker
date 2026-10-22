package hx.model;

import haxe.crypto.Sha256;
import haxe.ds.ObjectMap;
import hx.animation3d.AnimationClip3D.AnimationTrack3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.material.TextureWrap3D;
import hx.model.ModelAssetData.ModelPrimitiveData;
import hx.model.ModelAssetData.ModelBuildStats;
import hx.model.ModelSourceData.ModelNodeData;
import hx.model.ModelSourceData.ModelPrimitiveSource;
import hx.model.ModelSourceData.ModelMaterialData;
import hx.model.ModelSourceData.ModelSkinData;
import hx.model.ModelSourceData.ModelAnimationData;

/** 与源格式无关的构建边界：校验并复制输入，所有派生信息只计算一次。 */
class ModelAssetBuilder {
	/** 构建结果交给 ModelAsset 独占持有；调用方不得在交付后修改结果数组。 */
	public static function build(source:ModelSourceData):ModelAssetData {
		if (source == null || source.nodes == null || source.meshes == null || source.scenes == null
			|| source.materials == null || source.images == null || source.textures == null || source.skins == null
			|| source.animations == null || source.warnings == null || source.sourceFormat == null)
			throw "模型资产定义不完整";
		var warnings = source.warnings.copy();
		var stats:ModelBuildStats = {vertexCount: 0, triangleCount: 0, primitiveCount: 0, generatedNormalCount: 0, rigidPrimitiveCount: 0};
		var images = [for (image in source.images) {
			if (image == null || image.name == null || image.bytes == null || image.bytes.length == 0
				|| (image.mimeType != "image/png" && image.mimeType != "image/jpeg"))
				throw "模型图片必须提供名称、PNG/JPEG 类型和有效字节";
			var bytes = image.bytes.sub(0, image.bytes.length);
			{name: image.name, mimeType: image.mimeType, bytes: bytes, contentHash: Sha256.make(bytes).toHex()};
		}];
		var textures = [for (texture in source.textures) {
			if (texture == null) throw "模型纹理定义不能为空";
			checkIndex(texture.source, images.length, "纹理图片");
			checkWrap(texture.wrapU);
			checkWrap(texture.wrapV);
			var minFilter = hx.material.TextureMinFilter3D.resolve(texture.minFilter, texture.minSmoothing);
			hx.material.TextureMinFilter3D.validate(minFilter);
			{source: texture.source, wrapU: texture.wrapU, wrapV: texture.wrapV,
				smoothing: texture.smoothing, minSmoothing: hx.material.TextureMinFilter3D.base(minFilter) == 9729, minFilter: minFilter};
		}];
		var materials = [for (material in source.materials) copyMaterial(material, textures.length)];
		var meshes:Array<Array<ModelPrimitiveData>> = [];
		for (mesh in source.meshes) {
			if (mesh == null || mesh.length == 0) throw "模型网格缺少图元";
			meshes.push([for (primitive in mesh) buildPrimitive(primitive, materials.length, stats, warnings)]);
		}
		var nodes = [for (node in source.nodes) copyNode(node, meshes.length, source.skins.length)];
		var parents = [for (_ in nodes) -1];
		for (i in 0...nodes.length)
			for (child in nodes[i].children) {
				checkIndex(child, nodes.length, "子节点");
				if (parents[child] >= 0) throw "模型节点存在重复父级或重复子节点";
				parents[child] = i;
			}
		var roots = [for (i in 0...nodes.length) if (parents[i] < 0) i];
		var order = traverse(nodes, roots);
		if (order.length != nodes.length) throw "模型节点层级包含循环";
		var scenes = [for (scene in source.scenes) {
			if (scene == null) throw "模型场景定义不能为空";
			var seen:Map<Int, Bool> = [];
			for (root in scene) {
				checkIndex(root, nodes.length, "场景根节点");
				if (parents[root] >= 0 || seen.exists(root)) throw "模型场景根节点重复或存在父级";
				seen.set(root, true);
			}
			scene.copy();
		}];
		checkIndex(source.scene, scenes.length, "默认场景");
		var skins = [for (skin in source.skins) copySkin(skin, nodes.length)];
		for (node in nodes)
			if (node.skin >= 0) {
				if (node.mesh < 0) throw "模型蒙皮节点缺少网格";
				for (primitive in meshes[node.mesh]) {
					if (primitive.joints.length == 0) throw "蒙皮网格缺少关节和权重";
					for (joint in primitive.joints) checkIndex(joint, skins[node.skin].joints.length, "顶点关节");
				}
			}
		// GLB 多个轨道经常共用时间轴，复制后仍保留这部分只读共享。
		var timeCache = new ObjectMap<Array<Float>, Array<Float>>();
		var animations = [for (animation in source.animations) copyAnimation(animation, nodes, timeCache)];
		var names:Map<String, Bool> = [];
		for (animation in animations) {
			if (names.exists(animation.name)) throw "模型动画片段名称重复";
			names.set(animation.name, true);
		}
		return {
			dataVersion: ModelAssetSchema.DATA_VERSION, buildVersion: ModelAssetSchema.BUILD_VERSION,
			sourceFormat: source.sourceFormat, nodes: nodes, parents: parents, scenes: scenes, scene: source.scene,
			sceneNodes: [for (scene in scenes) traverse(nodes, scene)], meshes: meshes, materials: materials,
			images: images, textures: textures, skins: skins, animations: animations, warnings: warnings, stats: stats
		};
	}

	private static function buildPrimitive(source:ModelPrimitiveSource, materialCount:Int, stats:ModelBuildStats,
		warnings:Array<String>):ModelPrimitiveData {
		if (source == null || source.positions == null || source.positions.length % 3 != 0
			|| source.indices == null || source.indices.length % 3 != 0 || source.normals == null
			|| source.joints == null || source.weights == null)
			throw "模型图元数组布局无效";
		checkOptionalIndex(source.material, materialCount, "图元材质");
		var positions = floats(source.positions, -1, "顶点位置"), count = Std.int(positions.length / 3);
		var uvs = floats(source.uvs, count * 2, "顶点 UV"), indices = source.indices.copy();
		for (index in indices) checkIndex(index, count, "三角形顶点");
		var generated = source.normals.length == 0;
		var normals = generated ? ModelGeometryTools.generateNormals(positions, indices) : floats(source.normals, positions.length, "顶点法线");
		// 法线计算中的溢出也必须在资产进入运行时前拒绝。
		for (value in normals) checkFinite(value, "顶点法线");
		var tangents = source.tangents == null ? [] : floats(source.tangents, source.tangents.length == 0 ? 0 : count * 4, "顶点切线");
		for (vertex in 0...Std.int(tangents.length / 4)) {
			var offset = vertex * 4;
			if (tangents[offset] * tangents[offset] + tangents[offset + 1] * tangents[offset + 1] + tangents[offset + 2] * tangents[offset + 2] < 1e-12
				|| Math.abs(tangents[offset + 3]) != 1) throw "切线方向必须非零，手性必须为正负 1";
		}
		var bounds:Array<Float> = [];
		if (count > 0) {
			bounds = [positions[0], positions[1], positions[2], positions[0], positions[1], positions[2]];
			for (vertex in 1...count)
				for (axis in 0...3) {
					var value = positions[vertex * 3 + axis];
					bounds[axis] = Math.min(bounds[axis], value);
					bounds[axis + 3] = Math.max(bounds[axis + 3], value);
				}
		}
		var joints = source.joints.copy(), weights = floats(source.weights, -1, "关节权重"), rigid = -1;
		if (joints.length != 0 || weights.length != 0) {
			if (joints.length != count * 4 || weights.length != count * 4) throw "蒙皮关节与权重数量不匹配";
			var candidate = -1, isRigid = true, normalized = false;
			for (vertex in 0...count) {
				var sum = 0., influences = 0;
				for (slot in 0...4) {
					var i = vertex * 4 + slot, weight = weights[i];
					if (joints[i] < 0 || weight < 0 || weight > 1) throw "蒙皮关节或权重无效";
					sum += weight;
				}
				if (sum <= 1e-12) throw "蒙皮顶点权重总和为零";
				if (Math.abs(sum - 1) > 1e-5) normalized = true;
				for (slot in 0...4) {
					var i = vertex * 4 + slot;
					weights[i] /= sum;
					if (weights[i] == 0) continue;
					influences++;
					if (weights[i] != 1 || (candidate >= 0 && candidate != joints[i])) isRigid = false;
					candidate = joints[i];
				}
				if (influences != 1) isRigid = false;
			}
			if (normalized && warnings.indexOf("模型资产构建时已归一化蒙皮权重。") < 0)
				warnings.push("模型资产构建时已归一化蒙皮权重。");
			if (isRigid) rigid = candidate;
		}
		var triangles = Std.int(indices.length / 3);
		stats.vertexCount += count;
		stats.triangleCount += triangles;
		stats.primitiveCount++;
		if (generated) stats.generatedNormalCount++;
		if (rigid >= 0) stats.rigidPrimitiveCount++;
		return {positions: positions, normals: normals, tangents: tangents, uvs: uvs, indices: indices, joints: joints, weights: weights,
			material: source.material, bounds: bounds, triangleCount: triangles, generatedNormals: generated, rigidJoint: rigid};
	}

	private static function copyNode(node:ModelNodeData, meshCount:Int, skinCount:Int):ModelNodeData {
		if (node == null || node.name == null || node.children == null) throw "模型节点定义无效";
		checkOptionalIndex(node.mesh, meshCount, "节点网格");
		checkOptionalIndex(node.skin, skinCount, "节点蒙皮");
		var translation = floats(node.translation, 3, "节点平移"), rotation = floats(node.rotation, 4, "节点旋转");
		var scale = floats(node.scale, 3, "节点缩放");
		normalizeQuaternion(rotation, 0);
		checkScale(scale, 0);
		return {name: node.name, children: node.children.copy(), mesh: node.mesh, skin: node.skin,
			matrix: node.matrix == null ? null : matrix(node.matrix), translation: translation, rotation: rotation, scale: scale};
	}

	private static function copyMaterial(material:ModelMaterialData, textureCount:Int):ModelMaterialData {
		if (material == null || material.name == null) throw "模型材质定义无效";
		checkOptionalIndex(material.baseColorTexture, textureCount, "材质纹理");
		var mr = optionalTexture(material.metallicRoughnessTexture, textureCount);
		var normal = optionalTexture(material.normalTexture, textureCount);
		var ao = optionalTexture(material.occlusionTexture, textureCount);
		var emission = optionalTexture(material.emissiveTexture, textureCount);
		var normalScale:Float = material.normalScale == null ? 1 : material.normalScale;
		var aoStrength:Float = material.occlusionStrength == null ? 1 : material.occlusionStrength;
		checkFinite(normalScale, "法线贴图系数"); unit(aoStrength, "AO 强度");
		var color = floats(material.baseColorFactor, 4, "材质基础颜色"), emissive = floats(material.emissiveFactor, 3, "材质自发光");
		for (value in color) unit(value, "材质基础颜色");
		for (value in emissive) unit(value, "材质自发光");
		unit(material.opacity, "材质透明度");
		unit(material.alphaCutoff, "材质裁剪阈值");
		unit(material.metallicFactor, "材质金属度");
		unit(material.roughnessFactor, "材质粗糙度");
		if (material.alphaMode != AlphaMode3D.OPAQUE && material.alphaMode != AlphaMode3D.MASK && material.alphaMode != AlphaMode3D.BLEND)
			throw "模型材质透明模式无效";
		if (material.cullMode != CullMode3D.NONE && material.cullMode != CullMode3D.BACK && material.cullMode != CullMode3D.FRONT)
			throw "模型材质剔除模式无效";
		if (material.color < 0 || material.color > 0xffffff) throw "模型材质颜色无效";
		return {name: material.name, baseColorFactor: color, metallicFactor: material.metallicFactor,
			roughnessFactor: material.roughnessFactor, emissiveFactor: emissive, color: material.color,
			opacity: material.opacity, alphaMode: material.alphaMode, alphaCutoff: material.alphaCutoff,
			cullMode: material.cullMode, baseColorTexture: material.baseColorTexture,
			metallicRoughnessTexture: mr, normalTexture: normal, occlusionTexture: ao, emissiveTexture: emission,
			normalScale: normalScale, occlusionStrength: aoStrength};
	}

	private static function optionalTexture(index:Null<Int>, count:Int):Int {
		var result:Int = index == null ? -1 : index;
		checkOptionalIndex(result, count, "PBR 纹理");
		return result;
	}

	private static function copySkin(skin:ModelSkinData, nodeCount:Int):ModelSkinData {
		if (skin == null || skin.joints == null || skin.joints.length == 0 || skin.inverseBindMatrices == null
			|| skin.inverseBindMatrices.length != skin.joints.length) throw "模型蒙皮定义无效";
		var seen:Map<Int, Bool> = [];
		for (joint in skin.joints) {
			checkIndex(joint, nodeCount, "骨骼节点");
			if (seen.exists(joint)) throw "模型蒙皮关节重复";
			seen.set(joint, true);
		}
		return {joints: skin.joints.copy(), inverseBindMatrices: [for (value in skin.inverseBindMatrices) matrix(value)]};
	}

	private static function copyAnimation(animation:ModelAnimationData, nodes:Array<ModelNodeData>,
		timeCache:ObjectMap<Array<Float>, Array<Float>>):ModelAnimationData {
		if (animation == null || animation.name == null || animation.tracks == null || animation.tracks.length == 0)
			throw "模型动画定义无效";
		var targets:Map<String, Bool> = [], tracks:Array<AnimationTrack3D> = [];
		for (track in animation.tracks) {
			if (track == null) throw "模型动画轨道不能为空";
			checkIndex(track.node, nodes.length, "动画目标节点");
			if (nodes[track.node].matrix != null) throw "动画目标节点不能使用静态矩阵";
			if (["translation", "rotation", "scale"].indexOf(track.path) < 0
				|| ["LINEAR", "STEP"].indexOf(track.interpolation) < 0) throw "模型动画通道或插值方式无效";
			var key = track.node + ":" + track.path;
			if (targets.exists(key)) throw "模型动画包含重复目标通道";
			targets.set(key, true);
			if (track.times == null) throw "动画时间数组不能为空";
			var times = timeCache.get(track.times), width = track.path == "rotation" ? 4 : 3;
			if (times == null) {
				times = floats(track.times, -1, "动画时间");
				timeCache.set(track.times, times);
			}
			if (times.length == 0) throw "模型动画轨道没有关键帧";
			var values = floats(track.values, times.length * width, "动画值");
			for (i in 0...times.length) {
				if (times[i] < 0 || (i > 0 && times[i] <= times[i - 1])) throw "模型动画时间必须非负且严格递增";
				if (track.path == "rotation") normalizeQuaternion(values, i * 4);
				if (track.path == "scale") {
					checkScale(values, i * 3);
					if (track.interpolation == "LINEAR" && i > 0)
						for (axis in 0...3)
							if (values[i * 3 + axis] * values[(i - 1) * 3 + axis] < 0) throw "模型缩放动画不能跨越零";
				}
			}
			tracks.push({node: track.node, path: track.path, interpolation: track.interpolation, times: times, values: values});
		}
		return {name: animation.name, tracks: tracks};
	}

	/** 使用显式栈遍历，避免运行时逐实例递归分析层级。 */
	private static function traverse(nodes:Array<ModelNodeData>, roots:Array<Int>):Array<Int> {
		// 与既有 GLB 解析器一致，根节点深度为零。
		var stack = roots.copy(), depths = [for (_ in roots) 0], result:Array<Int> = [];
		stack.reverse();
		while (stack.length > 0) {
			var index:Int = stack.pop(), depth:Int = depths.pop();
			if (depth > 256) throw "模型节点层级超过支持的 256 层";
			result.push(index);
			var children = nodes[index].children;
			for (i in 0...children.length) {
				stack.push(children[children.length - 1 - i]);
				depths.push(depth + 1);
			}
		}
		return result;
	}

	private static function floats(values:Array<Float>, count:Int, label:String):Array<Float> {
		if (values == null || (count >= 0 && values.length != count)) throw label + "数量无效";
		for (value in values) checkFinite(value, label);
		return values.copy();
	}

	private static function matrix(values:Array<Float>):Array<Float> {
		var result = floats(values, 16, "矩阵");
		if (Math.abs(result[3]) > 1e-9 || Math.abs(result[7]) > 1e-9 || Math.abs(result[11]) > 1e-9
			|| Math.abs(result[15] - 1) > 1e-9) throw "模型矩阵必须为仿射矩阵";
		var determinant = result[0] * (result[5] * result[10] - result[9] * result[6])
			- result[4] * (result[1] * result[10] - result[9] * result[2])
			+ result[8] * (result[1] * result[6] - result[5] * result[2]);
		checkFinite(determinant, "矩阵行列式");
		if (Math.abs(determinant) < 1e-12) throw "模型矩阵必须可逆";
		return result;
	}

	private static function normalizeQuaternion(values:Array<Float>, offset:Int):Void {
		var length = 0.;
		for (i in 0...4) length += values[offset + i] * values[offset + i];
		checkFinite(length, "四元数长度");
		if (length < 1e-12) throw "模型旋转四元数长度无效";
		length = Math.sqrt(length);
		for (i in 0...4) values[offset + i] /= length;
	}

	private static function checkScale(values:Array<Float>, offset:Int):Void {
		for (axis in 0...3)
			if (Math.abs(values[offset + axis]) < 1e-8) throw "模型缩放不能为零或接近零";
		var determinant = values[offset] * values[offset + 1] * values[offset + 2];
		checkFinite(determinant, "缩放行列式");
		if (Math.abs(determinant) < 1e-12) throw "模型缩放超出可逆矩阵范围";
	}

	private static function checkWrap(value:TextureWrap3D):Void {
		if (value != TextureWrap3D.CLAMP && value != TextureWrap3D.REPEAT && value != TextureWrap3D.MIRROR)
			throw "模型纹理包裹模式无效";
	}

	private static function checkFinite(value:Float, label:String):Void {
		if (!Math.isFinite(value)) throw label + "包含非有限数值";
	}

	private static function unit(value:Float, label:String):Void {
		checkFinite(value, label);
		if (value < 0 || value > 1) throw label + "超出 0～1";
	}

	private static function checkIndex(value:Int, count:Int, label:String):Void {
		if (value < 0 || value >= count) throw label + "索引越界";
	}

	private static function checkOptionalIndex(value:Int, count:Int, label:String):Void {
		if (value != -1) checkIndex(value, count, label);
	}
}
