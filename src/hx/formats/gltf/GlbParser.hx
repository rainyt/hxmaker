package hx.formats.gltf;

import haxe.Json;
import haxe.io.Bytes;
import hx.geom.Matrix3D;
import hx.render3d.Math3D;
import hx.animation3d.AnimationClip3D;
import hx.animation3d.AnimationClip3D.AnimationTrack3D;
import hx.formats.gltf.GltfData.GltfNodeData;
import hx.formats.gltf.GltfData.GltfPrimitiveData;
import hx.formats.gltf.GltfData.GltfMaterialData;
import hx.formats.gltf.GltfData.GltfSkinData;

private typedef AccessorData = {
	var values:Array<Float>;
	var count:Int;
	var type:String;
	var component:Int;
	var normalized:Bool;
}

/** 无平台依赖的 GLB 2.0 子集解析器；不支持的功能明确报错，不静默误读。 */
class GlbParser {
	private var document:Dynamic;
	private var binary:Bytes;
	private var bufferLength:Int;
	private var views:Array<Dynamic>;
	private var accessors:Array<Dynamic>;
	private var cache:Map<Int, AccessorData> = [];
	private var warnings:Array<String> = ["GLB 外观以基础颜色为主，尚未实现 PBR 金属度和粗糙度。"];
	private function new() {}
	public static function parse(bytes:Bytes):GltfData { return new GlbParser().read(bytes); }

	private function read(bytes:Bytes):GltfData {
		if (bytes == null || bytes.length < 20) throw "GLB 文件头不完整";
		if (bytes.getInt32(0) != 0x46546c67 || bytes.getInt32(4) != 2) throw "只支持 GLB 2.0 文件";
		if (unsigned32(bytes, 8) != bytes.length) throw "GLB 声明长度与文件长度不一致";
		var offset = 12, first = true;
		while (offset < bytes.length) {
			if (bytes.length - offset < 8) throw "GLB 块头不完整";
			var size = unsigned32(bytes, offset), type = bytes.getInt32(offset + 4); offset += 8;
			if (size % 4 != 0 || size > bytes.length - offset) throw "GLB 块长度越界或未按四字节对齐";
			if (first && type != 0x4e4f534a) throw "GLB 第一个块必须为 JSON";
			first = false;
			switch (type) {
				case 0x4e4f534a:
					if (document != null) throw "GLB 包含重复 JSON 块";
					document = Json.parse(bytes.getString(offset, Std.int(size)));
				case 0x004e4942:
					if (binary != null) throw "GLB 包含重复 BIN 块";
					binary = bytes.sub(offset, Std.int(size));
				default:
					warn("已跳过未知 GLB 块：" + type);
			}
			offset += Std.int(size);
		}
		if (document == null || binary == null) throw "GLB 缺少 JSON 或内嵌 BIN";
		var asset = field(document, "asset");
		if (asset == null || text(asset, "version", "") != "2.0") throw "glTF asset.version 必须为 2.0";
		if (field(asset, "minVersion") != null && text(asset, "minVersion", "") != "2.0") throw "当前解析器不支持所需 glTF 最低版本";
		var required = list(document, "extensionsRequired");
		if (required.length > 0) throw "暂不支持必需 glTF 扩展：" + required.join(", ");
		for (extension in list(document, "extensionsUsed")) warn("未实现的可选 glTF 扩展：" + Std.string(extension));
		if (list(document, "images").length > 0 || list(document, "textures").length > 0)
			throw "首版 GLB 加载器暂不支持图片和纹理材质";
		var buffers = list(document, "buffers");
		if (buffers.length != 1 || field(buffers[0], "uri") != null) throw "首版只支持一个内嵌 BIN 缓冲，不支持外部 URI";
		bufferLength = integer(buffers[0], "byteLength", -1);
		if (bufferLength < 1 || bufferLength > binary.length || binary.length - bufferLength > 3) throw "GLB BIN 与 buffer 长度不一致";
		views = list(document, "bufferViews"); accessors = list(document, "accessors");
		for (i in 0...views.length) validateView(i);
		var materials = readMaterials(), meshes = readMeshes(materials.length), nodes = readNodes(meshes.length);
		var parents = [for (_ in nodes) -1];
		for (i in 0...nodes.length) for (child in nodes[i].children) {
			if (parents[child] != -1) throw "节点有重复父级：" + child;
			parents[child] = i;
		}
		var visited = [for (_ in nodes) 0], heights = [for (_ in nodes) 0];
		function visit(index:Int, depth:Int):Void {
			if (depth > 256) throw "GLB 节点层级超过首版支持的 256 层";
			if (visited[index] == 1) throw "GLB 节点树包含循环";
			if (visited[index] == 2) return;
			visited[index] = 1;
			for (child in nodes[index].children) { visit(child, depth + 1); heights[index] = Std.int(Math.max(heights[index], heights[child] + 1)); }
			if (heights[index] > 256) throw "GLB 节点层级超过首版支持的 256 层";
			visited[index] = 2;
		}
		for (i in 0...nodes.length) visit(i, 0);
		var scenes:Array<Array<Int>> = [];
		for (scene in list(document, "scenes")) {
			var roots:Array<Int> = [];
			for (value in list(scene, "nodes")) {
				var root = indexValue(value, nodes.length, "场景根节点");
				if (parents[root] != -1 || roots.indexOf(root) >= 0) throw "场景根节点重复或存在父级";
				roots.push(root);
			}
			scenes.push(roots);
		}
		if (scenes.length == 0) throw "GLB 没有可实例化场景";
		var scene = integer(document, "scene", 0); checkIndex(scene, scenes.length, "默认场景");
		var skins = readSkins(nodes.length);
		for (node in nodes) if (node.skin >= 0) {
			checkIndex(node.skin, skins.length, "skin");
			if (node.mesh < 0) throw "蒙皮节点缺少 mesh";
			for (primitive in meshes[node.mesh]) {
				if (primitive.joints.length == 0) throw "蒙皮网格缺少 JOINTS_0 / WEIGHTS_0";
				for (joint in primitive.joints) checkIndex(joint, skins[node.skin].joints.length, "顶点关节索引");
			}
		}
		return {nodes:nodes, parents:parents, scenes:scenes, scene:scene, meshes:meshes, materials:materials,
			skins:skins, animations:readAnimations(nodes), warnings:warnings};
	}

	private function readMaterials():Array<GltfMaterialData> {
		var result:Array<GltfMaterialData> = [];
		for (material in list(document, "materials")) {
			var pbr = field(material, "pbrMetallicRoughness");
			if (field(pbr, "baseColorTexture") != null || field(pbr, "metallicRoughnessTexture") != null
				|| field(material, "normalTexture") != null || field(material, "occlusionTexture") != null || field(material, "emissiveTexture") != null)
				throw "首版 GLB 加载器暂不支持纹理材质";
			var color = vector(pbr, "baseColorFactor", [1.,1.,1.,1.]);
			for (value in color) if (value < 0 || value > 1) throw "材质基础颜色超出 0～1";
			var metallic = number(pbr, "metallicFactor", 1), roughness = number(pbr, "roughnessFactor", 1);
			if (metallic < 0 || metallic > 1 || roughness < 0 || roughness > 1) throw "材质金属度或粗糙度超出 0～1";
			var emissive = vector(material, "emissiveFactor", [0.,0.,0.]);
			for (value in emissive) if (value < 0 || value > 1) throw "材质自发光颜色超出 0～1";
			var alpha = text(material, "alphaMode", "OPAQUE"), cutoff = number(material, "alphaCutoff", 0.5);
			if (["OPAQUE", "MASK", "BLEND"].indexOf(alpha) < 0 || cutoff < 0 || cutoff > 1) throw "材质透明模式或阈值无效";
			if (field(material, "emissiveFactor") != null) warn("自发光颜色尚未参与渲染。");
			result.push({name:text(material, "name", "材质 " + result.length), baseColorFactor:color, metallicFactor:metallic, roughnessFactor:roughness, emissiveFactor:emissive,
				color:(colorByte(color[0]) << 16) | (colorByte(color[1]) << 8) | colorByte(color[2]),
				opacity:color[3], alphaMode:alpha, alphaCutoff:cutoff, doubleSided:boolean(material, "doubleSided", false)});
		}
		return result;
	}
	/** 基础颜色因子为线性值，现有无光照顶点颜色按显示色值输出。 */
	private static function colorByte(value:Float):Int {
		return Std.int(Math.round(255 * (value <= 0.0031308 ? value * 12.92 : 1.055 * Math.pow(value, 1 / 2.4) - 0.055)));
	}

	private function readMeshes(materialCount:Int):Array<Array<GltfPrimitiveData>> {
		var result:Array<Array<GltfPrimitiveData>> = [];
		for (mesh in list(document, "meshes")) {
			if (field(mesh, "weights") != null) throw "首版暂不支持 morph weights";
			var primitives:Array<GltfPrimitiveData> = [];
			for (primitive in list(mesh, "primitives")) {
				if (integer(primitive, "mode", 4) != 4) throw "首版只支持 TRIANGLES 图元";
				if (field(primitive, "targets") != null) throw "首版暂不支持 morph targets";
				var attributes = field(primitive, "attributes");
				if (attributes == null) throw "网格缺少 attributes";
				for (name in Reflect.fields(attributes)) if (["POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"].indexOf(name) < 0)
					throw "首版暂不支持顶点属性：" + name;
				var position = attribute(attributes, "POSITION", "VEC3", -1);
				if (position == null || position.component != 5126 || position.normalized) throw "POSITION 必须为浮点 VEC3";
				var count = position.count, normal = attribute(attributes, "NORMAL", "VEC3", count), uv = attribute(attributes, "TEXCOORD_0", "VEC2", count);
				if (normal != null && (normal.component != 5126 || normal.normalized)) throw "NORMAL 必须为浮点 VEC3";
				if (uv != null && uv.component != 5126 && !((uv.component == 5121 || uv.component == 5123) && uv.normalized)) throw "TEXCOORD_0 组件类型无效";
				var indices:Array<Int> = [];
				if (field(primitive, "indices") == null) indices = [for (i in 0...count) i];
				else {
					var accessor = readAccessor(integer(primitive, "indices", -1));
					if (accessor.type != "SCALAR" || [5121,5123,5125].indexOf(accessor.component) < 0 || accessor.normalized) throw "索引必须为无符号整数 SCALAR";
					var restart:Float = accessor.component == 5121 ? 255. : accessor.component == 5123 ? 65535. : 4294967295.;
					for (value in accessor.values) {
						if (value == restart) throw "glTF 索引不能使用图元重启保留值";
						indices.push(indexValue(value, count, "三角形顶点索引"));
					}
				}
				if (indices.length % 3 != 0) throw "三角形索引数量必须为三的倍数";
				var joint = attribute(attributes, "JOINTS_0", "VEC4", count), weight = attribute(attributes, "WEIGHTS_0", "VEC4", count);
				var joints:Array<Int> = [], weights:Array<Float> = [];
				if ((joint == null) != (weight == null)) throw "JOINTS_0 与 WEIGHTS_0 必须同时提供";
				if (joint != null) {
					if ([5121,5123].indexOf(joint.component) < 0 || joint.normalized) throw "JOINTS_0 必须为未归一化的无符号整数";
					if (weight.component != 5126 && !((weight.component == 5121 || weight.component == 5123) && weight.normalized)) throw "WEIGHTS_0 组件类型无效";
					joints = [for (value in joint.values) Std.int(value)]; weights = weight.values.copy();
					for (vertex in 0...count) {
						var sum = 0.; for (i in 0...4) { var value = weights[vertex*4+i]; if (value < 0 || value > 1) throw "蒙皮权重超出 0～1"; sum += value; }
						if (sum <= 1e-12) throw "蒙皮顶点的权重总和为零";
						if (Math.abs(sum - 1) > 1e-5) warn("蒙皮权重已归一化。");
						for (i in 0...4) weights[vertex*4+i] /= sum;
					}
				}
				var material = integer(primitive, "material", -1); if (material < -1) throw "材质索引无效";
				if (material >= 0) checkIndex(material, materialCount, "材质");
				primitives.push({positions:position.values, normals:normal == null ? [] : normal.values,
					uvs:uv == null ? [for (_ in 0...(count*2)) 0.] : uv.values, indices:indices, joints:joints, weights:weights, material:material});
			}
			if (primitives.length == 0) throw "网格没有 primitive";
			result.push(primitives);
		}
		return result;
	}

	private function readNodes(meshCount:Int):Array<GltfNodeData> {
		var raw = list(document, "nodes"), result:Array<GltfNodeData> = [];
		for (node in raw) {
			var children:Array<Int> = [for (child in list(node, "children")) indexValue(child, raw.length, "子节点")];
			var mesh = integer(node, "mesh", -1), skin = integer(node, "skin", -1);
			if (mesh < -1 || skin < -1) throw "节点 mesh / skin 索引无效";
			if (mesh >= 0) checkIndex(mesh, meshCount, "mesh");
			if (field(node, "weights") != null) throw "首版暂不支持节点 morph weights";
			if (field(node, "camera") != null) warn("GLB 内置相机未导入，使用示例相机取景。");
			var matrix:Array<Float> = null;
			if (field(node, "matrix") != null) {
				for (key in ["translation", "rotation", "scale"]) if (field(node, key) != null) throw "节点不能同时包含 matrix 与 TRS";
				matrix = vector(node, "matrix", [for (_ in 0...16) 0.]); validateMatrix(matrix);
			}
			var t = vector(node, "translation", [0.,0.,0.]), q = vector(node, "rotation", [0.,0.,0.,1.]), s = vector(node, "scale", [1.,1.,1.]);
			normalizeQuaternion(q); validateScale(s);
			result.push({name:text(node, "name", "节点 " + result.length), children:children, mesh:mesh, skin:skin, matrix:matrix, translation:t, rotation:q, scale:s});
		}
		return result;
	}

	private function readSkins(nodeCount:Int):Array<GltfSkinData> {
		var result:Array<GltfSkinData> = [];
		for (skin in list(document, "skins")) {
			var joints:Array<Int> = [];
			for (value in list(skin, "joints")) {
				var joint = indexValue(value, nodeCount, "骨骼节点");
				if (joints.indexOf(joint) >= 0) throw "skin.joints 包含重复节点"; joints.push(joint);
			}
			if (joints.length == 0) throw "蒙皮缺少关节";
			if (field(skin, "skeleton") != null) checkIndex(integer(skin, "skeleton", -1), nodeCount, "骨架根节点");
			var matrices:Array<Array<Float>> = [];
			if (field(skin, "inverseBindMatrices") == null) matrices = [for (_ in joints) new Matrix3D().rawData];
			else {
				var data = readAccessor(integer(skin, "inverseBindMatrices", -1));
				if (data.type != "MAT4" || data.component != 5126 || data.normalized || data.count < joints.length) throw "逆绑定矩阵必须是足量浮点 MAT4";
				for (i in 0...joints.length) { var matrix = data.values.slice(i*16, i*16+16); validateMatrix(matrix); matrices.push(matrix); }
			}
			result.push({joints:joints, inverseBindMatrices:matrices});
		}
		return result;
	}

	private function readAnimations(nodes:Array<GltfNodeData>):Array<AnimationClip3D> {
		var result:Array<AnimationClip3D> = [], names:Map<String, Bool> = [];
		for (animation in list(document, "animations")) {
			var samplers = list(animation, "samplers"), tracks:Array<AnimationTrack3D> = [], targets:Map<String, Bool> = [];
			for (channel in list(animation, "channels")) {
				var target = field(channel, "target"), node = integer(target, "node", -1), path = text(target, "path", "");
				checkIndex(node, nodes.length, "动画目标节点");
				if (["translation", "rotation", "scale"].indexOf(path) < 0) throw "暂不支持动画通道：" + path;
				if (nodes[node].matrix != null) throw "动画目标节点不能使用 matrix";
				var targetKey = node + ":" + path;
				if (targets.exists(targetKey)) throw "动画包含重复目标通道"; targets.set(targetKey, true);
				var samplerIndex = integer(channel, "sampler", -1); checkIndex(samplerIndex, samplers.length, "动画 sampler");
				var sampler = samplers[samplerIndex], interpolation = text(sampler, "interpolation", "LINEAR");
				if (["STEP", "LINEAR"].indexOf(interpolation) < 0) throw "首版暂不支持动画插值：" + interpolation;
				var input = readAccessor(integer(sampler, "input", -1)), output = readAccessor(integer(sampler, "output", -1));
				if (input.type != "SCALAR" || input.component != 5126 || input.normalized || input.count == 0) throw "动画时间必须为浮点 SCALAR";
				for (i in 0...input.count) if (input.values[i] < 0 || (i > 0 && input.values[i] <= input.values[i-1])) throw "动画关键帧时间必须严格递增且非负";
				var width = path == "rotation" ? 4 : 3;
				if (output.type != (width == 4 ? "VEC4" : "VEC3") || output.component != 5126 || output.normalized || output.count != input.count)
					throw "动画输出类型或关键帧数量不匹配";
				var values = output.values.copy();
				for (i in 0...output.count) {
					if (path == "rotation") {
						var q = values.slice(i*4, i*4+4); normalizeQuaternion(q); for (j in 0...4) values[i*4+j] = q[j];
					} else if (path == "scale") {
						validateScale(values.slice(i*3, i*3+3));
						if (interpolation == "LINEAR" && i > 0) for (j in 0...3) if (values[i*3+j] * values[(i-1)*3+j] < 0) throw "首版暂不支持跨越零的缩放动画";
					}
				}
				tracks.push({node:node, path:path, interpolation:interpolation, times:input.values, values:values});
			}
			if (tracks.length == 0) throw "动画没有通道";
			var base = text(animation, "name", "动画 " + result.length), name = base, suffix = 2;
			while (names.exists(name)) name = base + " #" + suffix++;
			names.set(name, true); result.push(new AnimationClip3D(name, tracks));
		}
		return result;
	}

	private function attribute(attributes:Dynamic, name:String, type:String, count:Int):AccessorData {
		if (field(attributes, name) == null) return null;
		var data = readAccessor(integer(attributes, name, -1));
		if (data.type != type || (count >= 0 && data.count != count)) throw "顶点属性类型或数量不匹配：" + name;
		return data;
	}
	private function validateView(index:Int):Void {
		var view = views[index], offset = integer(view, "byteOffset", 0), length = integer(view, "byteLength", -1), stride = integer(view, "byteStride", 0);
		if (integer(view, "buffer", -1) != 0 || offset < 0 || length < 1 || offset > bufferLength - length) throw "bufferView 越界：" + index;
		if (stride != 0 && (stride < 4 || stride > 252 || stride % 4 != 0)) throw "bufferView.byteStride 无效：" + index;
	}
	private function readAccessor(index:Int):AccessorData {
		checkIndex(index, accessors.length, "accessor");
		var saved = cache.get(index); if (saved != null) return saved;
		var accessor = accessors[index];
		if (field(accessor, "sparse") != null) throw "首版暂不支持 sparse accessor：" + index;
		var viewIndex = integer(accessor, "bufferView", -1); checkIndex(viewIndex, views.length, "accessor.bufferView");
		var view = views[viewIndex], component = integer(accessor, "componentType", -1), type = text(accessor, "type", "");
		var size = switch (component) { case 5120,5121: 1; case 5122,5123: 2; case 5125,5126: 4; default: throw "无效 accessor 组件类型"; };
		var width = switch (type) { case "SCALAR": 1; case "VEC2": 2; case "VEC3": 3; case "VEC4": 4; case "MAT4": 16; default: throw "首版不支持 accessor 类型：" + type; };
		if (type == "MAT4" && component != 5126) throw "首版 MAT4 只支持浮点组件";
		var normalized = boolean(accessor, "normalized", false);
		if (normalized && (component == 5126 || component == 5125)) throw "当前 accessor 组件不能 normalized";
		var count = integer(accessor, "count", -1), offset = integer(accessor, "byteOffset", 0), stride = integer(view, "byteStride", width*size);
		var viewOffset = integer(view, "byteOffset", 0), viewLength = integer(view, "byteLength", -1);
		if (count < 1 || offset < 0 || offset % size != 0 || (viewOffset + offset) % size != 0 || stride < width*size || stride % size != 0
			|| offset + (count - 1.) * stride + width*size > viewLength) throw "accessor 长度、对齐或步长越界：" + index;
		var values:Array<Float> = [];
		for (i in 0...count) for (j in 0...width) {
			var at = viewOffset + offset + i*stride + j*size;
			var value:Float = switch (component) {
				case 5120: var v = binary.get(at); v >= 128 ? v - 256 : v;
				case 5121: binary.get(at);
				case 5122: var v = binary.getUInt16(at); v >= 32768 ? v - 65536 : v;
				case 5123: binary.getUInt16(at);
				case 5125: unsigned32(binary, at);
				case 5126: binary.getFloat(at);
				default: 0.;
			};
			if (!Math3D.finite(value)) throw "accessor 包含非有限数值：" + index;
			if (normalized) value = switch (component) {
				case 5120: Math.max(value/127, -1); case 5121: value/255;
				case 5122: Math.max(value/32767, -1); case 5123: value/65535; default: value;
			};
			values.push(value);
		}
		var result:AccessorData = {values:values, count:count, type:type, component:component, normalized:normalized};
		cache.set(index, result); return result;
	}

	private static function field(object:Dynamic, name:String):Dynamic { return object == null ? null : Reflect.field(object, name); }
	private static function list(object:Dynamic, name:String):Array<Dynamic> {
		var value = field(object, name); if (value == null) return [];
		if (!Std.isOfType(value, Array)) throw name + " 必须是数组"; return cast value;
	}
	private static function text(object:Dynamic, name:String, fallback:String):String {
		var value = field(object, name); if (value == null) return fallback;
		if (!Std.isOfType(value, String)) throw name + " 必须是字符串"; return cast value;
	}
	private static function boolean(object:Dynamic, name:String, fallback:Bool):Bool {
		var value = field(object, name); if (value == null) return fallback;
		if (!Std.isOfType(value, Bool)) throw name + " 必须是布尔值"; return cast value;
	}
	private static function numeric(value:Dynamic, label:String):Float {
		if ((!Std.isOfType(value, Float) && !Std.isOfType(value, Int)) || !Math3D.finite(cast value)) throw label + " 必须是有限数值";
		return cast value;
	}
	private static function number(object:Dynamic, name:String, fallback:Float):Float {
		var value = field(object, name); return value == null ? fallback : numeric(value, name);
	}
	private static function integer(object:Dynamic, name:String, fallback:Int):Int {
		var value = field(object, name); if (value == null) return fallback;
		var result = numeric(value, name);
		if (result != Math.floor(result) || result < -2147483648. || result > 2147483647.) throw name + " 必须是有效整数";
		return Std.int(result);
	}
	private static function vector(object:Dynamic, name:String, fallback:Array<Float>):Array<Float> {
		if (field(object, name) == null) return fallback.copy();
		var raw = list(object, name); if (raw.length != fallback.length) throw name + " 分量数量无效";
		return [for (value in raw) numeric(value, name)];
	}
	private static function checkIndex(index:Int, length:Int, label:String):Void { if (index < 0 || index >= length) throw label + " 索引越界：" + index; }
	private static function indexValue(value:Dynamic, length:Int, label:String):Int {
		var number = numeric(value, label);
		if (number < 0 || number >= length || number != Math.floor(number)) throw label + " 索引越界：" + number;
		return Std.int(number);
	}
	private static function unsigned32(bytes:Bytes, at:Int):Float {
		return bytes.get(at) + bytes.get(at+1)*256. + bytes.get(at+2)*65536. + bytes.get(at+3)*16777216.;
	}
	private static function normalizeQuaternion(q:Array<Float>):Void {
		var length = 0.; for (v in q) length += v*v;
		if (!Math3D.finite(length) || length < 1e-12) throw "旋转四元数长度无效";
		length = Math.sqrt(length); for (i in 0...4) q[i] /= length;
	}
	private static function validateScale(s:Array<Float>):Void {
		for (v in s) if (Math.abs(v) < 1e-8) throw "当前节点矩阵协议暂不支持零缩放或接近零的缩放";
		var determinant = s[0]*s[1]*s[2];
		if (!Math3D.finite(determinant) || Math.abs(determinant) < 1e-12) throw "缩放矩阵超出当前可逆矩阵支持范围";
	}
	private static function validateMatrix(values:Array<Float>):Void {
		for (value in values) if (!Math3D.finite(value)) throw "矩阵包含非有限数值";
		if (Math.abs(values[3]) > 1e-9 || Math.abs(values[7]) > 1e-9 || Math.abs(values[11]) > 1e-9 || Math.abs(values[15]-1) > 1e-9
			|| Math.abs(new Matrix3D(values).determinant) < 1e-12) throw "当前节点矩阵协议要求可逆仿射矩阵";
	}
	private function warn(message:String):Void { if (warnings.indexOf(message) < 0) warnings.push(message); }
}
