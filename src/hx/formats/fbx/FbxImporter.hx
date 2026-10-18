package hx.formats.fbx;

import haxe.Int64;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import hx.formats.fbx.FbxDocument.FbxElement;
import hx.formats.fbx.FbxDocument.FbxValue;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.material.TextureWrap3D;
import hx.model.ModelAssetBuilder;
import hx.model.ModelAssetData;
import hx.model.ModelSourceData;
import hx.model.ModelSourceData.ModelNodeData;
import hx.model.ModelSourceData.ModelPrimitiveSource;
import hx.model.ModelSourceData.ModelMaterialData;
import hx.model.ModelSourceData.ModelTextureData;
import hx.model.ModelSourceData.ModelImageSource;

private typedef FbxConnection = {var kind:String; var from:String; var to:String; var property:String;}
private typedef FbxLayer = {var mapping:String; var reference:String; var values:Array<Float>; var indices:Array<Float>; var width:Int;}

/** FBX 首版静态模型导入器。复杂变形和动画明确拒绝，避免以静止姿态冒充正确导入。 */
class FbxImporter {
	private var objects:Map<String, FbxElement> = [];
	private var links:Array<FbxConnection> = [];
	private var incoming:Map<String, Array<FbxConnection>> = [];
	private var materials:Array<ModelMaterialData> = [];
	private var materialIds:Map<String, Int> = [];
	private var images:Array<ModelImageSource> = [];
	private var imageIds:Map<String, Int> = [];
	private var textures:Array<ModelTextureData> = [];
	private var textureIds:Map<String, Int> = [];
	private var textureSets:Map<Int, String> = [];
	private var warnings:Array<String> = ["FBX 首版仅支持静态模型，材质以基础色和基础色贴图近似还原。"];
	private var mirrored:Bool = false;
	private var expandedVertices:Int = 0;

	private function new() {}

	public static function importBytes(bytes:Bytes):ModelAssetData {
		return new FbxImporter().read(FbxParser.parse(bytes));
	}

	private function read(document:FbxDocument):ModelAssetData {
		var objectSection = find(document.nodes, "Objects", true), connectionSection = find(document.nodes, "Connections", true);
		var models:Array<FbxElement> = [], modelIds:Map<String, Int> = [];
		for (object in objectSection.children) {
			if (object.properties.length < 3) throw "FBX 对象头不完整：" + object.name;
			var key = id(object.properties[0]);
			if (key == "0" || objects.exists(key)) throw "FBX 对象 ID 为零或重复：" + key;
			objects.set(key, object);
			if (child(object, "Properties60") != null) throw "FBX 首版只支持 Properties70 属性布局";
			switch (object.name) {
				case "Deformer", "AnimationStack", "AnimationLayer", "AnimationCurve", "AnimationCurveNode", "Constraint":
					throw "FBX 首版暂不支持骨骼、Morph、约束或动画：" + object.name + "；请使用静态模型，动画资源继续使用 GLB";
				case "Geometry":
					if (string(object.properties[2]) != "Mesh") throw "FBX 首版只支持 Mesh 几何";
				case "Model":
					if (string(object.properties[2]) == "LimbNode" || string(object.properties[2]) == "Root")
						throw "FBX 首版不导入骨架节点";
					modelIds.set(key, models.length); models.push(object);
				case "LayeredTexture": throw "FBX 首版暂不支持分层贴图";
				case "NodeAttribute", "Pose": warn("FBX 相机、灯光、节点附加属性或姿态定义未导入。");
				default:
			}
		}
		for (connection in connectionSection.children) {
			if (connection.name != "C" || connection.properties.length < 3) throw "FBX 连接记录无效";
			var kind = string(connection.properties[0]);
			if (kind != "OO" && kind != "OP") throw "FBX 首版只支持 OO/OP 对象连接";
			var from = id(connection.properties[1]), to = id(connection.properties[2]);
			if (!objects.exists(from) || (to != "0" && !objects.exists(to))) throw "FBX 连接引用不存在的对象";
			var link:FbxConnection = {kind: kind, from: from, to: to, property: connection.properties.length > 3 ? string(connection.properties[3]) : ""};
			links.push(link);
			if (!incoming.exists(to)) incoming.set(to, []);
			incoming.get(to).push(link);
		}
		for (object in objectSection.children)
			if (object.name == "Material") {
				materialIds.set(id(object.properties[0]), materials.length);
				materials.push(readMaterial(object));
			}
		var nodes:Array<ModelNodeData> = [], parents = [for (_ in models) -1];
		for (object in models) {
			if (propertyNumber(object, "RotationActive", 1) == 0
				&& (propertyNumber(object, "RotationOrder", 0) != 0 || nonzero(vector(object, "PreRotation", [0.,0.,0.]))
					|| nonzero(vector(object, "PostRotation", [0.,0.,0.]))))
				throw "FBX 未启用旋转空间却设置了特殊旋转，请在建模工具中烘焙变换";
			if (propertyNumber(object, "Visibility", 1) != 1) warn("FBX 首版未导入节点可见性属性，隐藏节点也会创建。");
			var matrix = FbxTransform.local(vector(object, "Lcl Translation", [0.,0.,0.]), vector(object, "Lcl Rotation", [0.,0.,0.]),
				vector(object, "Lcl Scaling", [1.,1.,1.]), integer(propertyNumber(object, "RotationOrder", 0)),
				vector(object, "PreRotation", [0.,0.,0.]), vector(object, "PostRotation", [0.,0.,0.]),
				vector(object, "RotationOffset", [0.,0.,0.]), vector(object, "RotationPivot", [0.,0.,0.]),
				vector(object, "ScalingOffset", [0.,0.,0.]), vector(object, "ScalingPivot", [0.,0.,0.]));
			nodes.push(node(name(object), matrix.rawData));
		}
		for (link in links)
			if (link.kind == "OO" && modelIds.exists(link.from) && modelIds.exists(link.to)) {
				var index = modelIds.get(link.from), parent = modelIds.get(link.to);
				if (parents[index] >= 0) throw "FBX 模型存在重复父级";
				parents[index] = parent; nodes[parent].children.push(index);
			}
		for (i in 0...models.length) checkInheritance(i, models, parents);
		var settings = find(document.nodes, "GlobalSettings"), basis = FbxTransform.basis(
			integer(propertyNumber(settings, "CoordAxis", 0)), integer(propertyNumber(settings, "CoordAxisSign", 1)),
			integer(propertyNumber(settings, "UpAxis", 1)), integer(propertyNumber(settings, "UpAxisSign", 1)),
			integer(propertyNumber(settings, "FrontAxis", 2)), integer(propertyNumber(settings, "FrontAxisSign", -1)),
			propertyNumber(settings, "UnitScaleFactor", 1) / 100);
		if (settings == null) warn("FBX 缺少全局设置，按右手系 Y 向上、厘米单位解释。");
		mirrored = basis.determinant < 0;
		var meshes:Array<Array<ModelPrimitiveSource>> = [], meshCache:Map<String, Int> = [];
		for (i in 0...models.length) {
			var model = models[i], key = id(model.properties[0]), slots:Array<Int> = [];
			for (link in connections(key))
				if (link.kind == "OO" && materialIds.exists(link.from)) slots.push(materialIds.get(link.from));
			for (link in connections(key))
				if (link.kind == "OO" && objects.get(link.from).name == "Geometry") {
					var cacheKey = link.from + "/" + slots.join(",");
					if (!meshCache.exists(cacheKey)) {
						meshCache.set(cacheKey, meshes.length);
						meshes.push(readGeometry(objects.get(link.from), slots));
					}
					var meshIndex = meshCache.get(cacheKey);
					// 几何变换只作用于网格，不传播到原模型的子节点。
					var helper = node(nodes[i].name + " / 网格 " + meshIndex, FbxTransform.geometric(
						vector(model, "GeometricTranslation", [0.,0.,0.]), vector(model, "GeometricRotation", [0.,0.,0.]),
						vector(model, "GeometricScaling", [1.,1.,1.])).rawData);
					helper.mesh = meshIndex; nodes[i].children.push(nodes.length); nodes.push(helper);
				}
		}
		if (meshes.length == 0) throw "FBX 没有连接到模型节点的 Mesh 网格";
		var root = node("FBX 坐标归一化", basis.rawData);
		root.children = [for (i in 0...models.length) if (parents[i] < 0) i];
		var rootIndex = nodes.length; nodes.push(root);
		var source:ModelSourceData = {sourceFormat: "fbx", nodes: nodes, scenes: [[rootIndex]], scene: 0, meshes: meshes,
			materials: materials, images: images, textures: textures, skins: [], animations: [], warnings: warnings};
		return ModelAssetBuilder.build(source);
	}

	private function checkInheritance(index:Int, models:Array<FbxElement>, parents:Array<Int>):Void {
		var mode = integer(propertyNumber(models[index], "InheritType", 0));
		if (mode < 0 || mode > 2) throw "FBX 缩放继承模式无效";
		var parent = parents[index], seen:Map<Int, Bool> = [], depth = 0;
		while (parent >= 0) {
			if (seen.exists(parent) || parent == index || ++depth > 256) throw "FBX 模型层级循环或深度超限";
			seen.set(parent, true);
			var scale = vector(models[parent], "Lcl Scaling", [1.,1.,1.]);
			if ((mode == 0 && (Math.abs(scale[0] - scale[1]) > 1e-8 || Math.abs(scale[1] - scale[2]) > 1e-8))
				|| (mode == 2 && (Math.abs(scale[0] - 1) > 1e-8 || Math.abs(scale[1] - 1) > 1e-8 || Math.abs(scale[2] - 1) > 1e-8)))
				throw "FBX 特殊缩放继承无法用当前节点树准确表达，请烘焙变换或使用 RSrs 继承";
			parent = parents[parent];
		}
	}

	private function readMaterial(object:FbxElement):ModelMaterialData {
		var diffuse = vector(object, "DiffuseColor", [0.8,0.8,0.8]), factor = propertyNumber(object, "DiffuseFactor", 1);
		var opacity = propertyNumber(object, "Opacity", 1 - propertyNumber(object, "TransparencyFactor", 0));
		for (i in 0...3) diffuse[i] = unit(diffuse[i] * factor);
		opacity = unit(opacity);
		var texture = -1, key = id(object.properties[0]);
		for (link in connections(key))
			if (objects.get(link.from).name == "Texture") {
				if (link.kind != "OP" || ["DiffuseColor", "Diffuse", "Maya|baseColor"].indexOf(link.property) < 0)
					throw "FBX 首版只支持基础颜色贴图连接：" + link.property;
				if (texture >= 0) throw "FBX 材质存在多张基础颜色贴图";
				texture = readTexture(link.from);
			}
		return {name: name(object), baseColorFactor: [diffuse[0],diffuse[1],diffuse[2],opacity], metallicFactor: 0., roughnessFactor: 1.,
			emissiveFactor: [0.,0.,0.], color: (colorByte(diffuse[0]) << 16) | (colorByte(diffuse[1]) << 8) | colorByte(diffuse[2]),
			opacity: opacity, alphaMode: opacity < 1 ? AlphaMode3D.BLEND : AlphaMode3D.OPAQUE,
			alphaCutoff: 0.5, cullMode: CullMode3D.NONE, baseColorTexture: texture};
	}

	private function readTexture(key:String):Int {
		if (textureIds.exists(key)) return textureIds.get(key);
		var texture = objects.get(key), videoKey:String = null;
		for (link in connections(key))
			if (link.kind == "OO" && objects.get(link.from).name == "Video") {
				if (videoKey != null) throw "FBX 纹理连接了多份图片内容";
				videoKey = link.from;
			}
		if (videoKey == null) throw "FBX 贴图缺少内嵌 Video，首版不加载外部贴图文件";
		if (propertyNumber(texture, "CurrentMappingType", 0) != 0 || propertyNumber(texture, "SwapUV", 0) != 0
			|| propertyNumber(texture, "UVSwap", 0) != 0 || childNumber(texture, "UVSwap", 0) != 0)
			throw "FBX 首版只支持未交换坐标的 UV 贴图映射";
		var crop = child(texture, "Cropping");
		if (crop != null) for (value in crop.properties) if (number(value) != 0) throw "FBX 首版不支持贴图裁剪";
		for (key in ["Translation", "Rotation", "Scaling"]) {
			var defaults = key == "Scaling" ? [1.,1.,1.] : [0.,0.,0.], values = vector(texture, key, defaults);
			for (i in 0...3) if (Math.abs(values[i] - defaults[i]) > 1e-8) throw "FBX 首版暂不支持贴图坐标变换";
		}
		for (key in ["ModelUVTranslation", "ModelUVScaling", "UVTranslation", "UVScaling"]) {
			var entry = child(texture, key);
			if (entry != null)
				for (value in entry.properties)
					if (Math.abs(number(value) - (key.indexOf("Scaling") >= 0 ? 1 : 0)) > 1e-8)
						throw "FBX 首版暂不支持贴图坐标变换";
		}
		var imageIndex:Int;
		if (imageIds.exists(videoKey)) imageIndex = imageIds.get(videoKey);
		else {
			var video = objects.get(videoKey), content = child(video, "Content"), data:Bytes = null;
			if (content == null || content.properties.length == 0) throw "FBX 贴图只有外部路径，请在导出时嵌入图片";
			if (content.properties.length == 1) switch (content.properties[0]) { case Binary(value): data = value; default: }
			if (data == null) {
				var encoded = new StringBuf();
				for (value in content.properties) encoded.add(string(value));
				data = Base64.decode(encoded.toString());
			}
			var mime = data.length >= 8 && data.get(0) == 137 && data.getString(1, 3) == "PNG" ? "image/png"
				: data.length >= 3 && data.get(0) == 255 && data.get(1) == 216 && data.get(2) == 255 ? "image/jpeg" : null;
			if (mime == null) throw "FBX 内嵌贴图只支持 PNG/JPEG";
			imageIndex = images.length; images.push({name: name(video), mimeType: mime, bytes: data}); imageIds.set(videoKey, imageIndex);
		}
		var wrapU = integer(childNumber(texture, "WrapModeU", 0)), wrapV = integer(childNumber(texture, "WrapModeV", 0));
		if ((wrapU != 0 && wrapU != 1) || (wrapV != 0 && wrapV != 1)) throw "FBX 纹理包裹模式不支持";
		var index = textures.length;
		textures.push({source: imageIndex, wrapU: wrapU == 1 ? TextureWrap3D.CLAMP : TextureWrap3D.REPEAT,
			wrapV: wrapV == 1 ? TextureWrap3D.CLAMP : TextureWrap3D.REPEAT, smoothing: true, minSmoothing: true, minFilter: 9729});
		var set = property(texture, "UVSet");
		textureSets.set(index, set == null ? "" : string(set[0])); textureIds.set(key, index);
		return index;
	}

	private function readGeometry(object:FbxElement, slots:Array<Int>):Array<ModelPrimitiveSource> {
		if (child(object, "LayerElementHole") != null) throw "FBX 首版不支持带孔多边形，请先三角化";
		var vertices = array(child(object, "Vertices", true)), polygonIndices = array(child(object, "PolygonVertexIndex", true));
		if (vertices.length == 0 || vertices.length % 3 != 0) throw "FBX 顶点位置布局无效";
		var normal = readLayer(object, "LayerElementNormal", "Normals", "NormalsIndex", 3);
		var uv = readLayer(object, "LayerElementUV", "UV", "UVIndex", 2);
		var material = layerElement(object, "LayerElementMaterial"), materialValues = material == null ? null : array(child(material, "Materials", true));
		if (material != null && ["Direct", "IndexToDirect"].indexOf(childString(material, "ReferenceInformationType", "IndexToDirect")) < 0)
			throw "FBX 材质引用模式不支持";
		var uvElement = layerElement(object, "LayerElementUV"), uvName = uvElement == null ? "" : childString(uvElement, "Name", "");
		if (normal == null) warn("FBX 网格缺少法线，已按共享顶点生成平滑法线；首版不解释平滑组。");
		if (child(object, "LayerElementColor") != null) warn("FBX 顶点颜色尚未导入。");
		var groups:Array<ModelPrimitiveSource> = [], groupsByMaterial:Map<Int, Int> = [], caches:Array<Map<String, Int>> = [];
		var polygon:Array<Int> = [], corners:Array<Int> = [], polygonIndex = 0;
		for (corner in 0...polygonIndices.length) {
			var encoded = integer(polygonIndices[corner]), index = encoded < 0 ? -encoded - 1 : encoded;
			if (index < 0 || index >= Std.int(vertices.length / 3)) throw "FBX 多边形顶点索引越界";
			polygon.push(index); corners.push(corner);
			if (polygon.length > 256) throw "FBX 多边形超过 256 个角点，请先三角化";
			if (encoded >= 0) continue;
			var slot = 0;
			if (material != null) {
				var mapping = childString(material, "MappingInformationType", "");
				if (mapping != "AllSame" && mapping != "ByPolygon") throw "FBX 材质只支持 AllSame/ByPolygon 映射";
				var at = mapping == "AllSame" ? 0 : polygonIndex;
				if (at >= materialValues.length) throw "FBX 面材质索引数量不足";
				slot = integer(materialValues[at]);
			}
			if (slot < -1 || (slots.length > 0 && slot >= slots.length) || (slots.length == 0 && slot > 0)) throw "FBX 面引用的材质槽越界";
			var materialIndex = slot < 0 || slots.length == 0 ? -1 : slots[slot];
			if (materialIndex >= 0 && materials[materialIndex].baseColorTexture >= 0) {
				if (uv == null) throw "FBX 带贴图网格缺少 UV";
				var set = textureSets.get(materials[materialIndex].baseColorTexture);
				if (set != "" && set != "default" && set != uvName) throw "FBX 纹理引用了首版不支持的其他 UV 集：" + set;
			}
			if (!groupsByMaterial.exists(materialIndex)) {
				groupsByMaterial.set(materialIndex, groups.length);
				groups.push({positions: [], normals: [], uvs: [], indices: [], joints: [], weights: [], material: materialIndex}); caches.push([]);
			}
			var groupIndex = groupsByMaterial.get(materialIndex), group = groups[groupIndex], cache = caches[groupIndex], mapped:Array<Int> = [];
			for (i in 0...polygon.length) {
				var n = layerIndex(normal, polygon[i], corners[i], polygonIndex), u = layerIndex(uv, polygon[i], corners[i], polygonIndex);
				var key = polygon[i] + ":" + n + ":" + u;
				if (!cache.exists(key)) {
					if (++expandedVertices > 2000000) throw "FBX 展开顶点数超过 200 万上限";
					cache.set(key, Std.int(group.positions.length / 3));
					for (axis in 0...3) group.positions.push(vertices[polygon[i] * 3 + axis]);
					if (normal != null) for (axis in 0...3) group.normals.push(normal.values[n * 3 + axis]);
					group.uvs.push(uv == null ? 0 : uv.values[u * 2]);
					// FBX 的 UV 原点通常位于左下，统一为当前 GLB 贴图路径的左上原点。
					group.uvs.push(uv == null ? 0 : 1 - uv.values[u * 2 + 1]);
				}
				mapped.push(cache.get(key));
			}
			var triangles = FbxTriangulator.triangulate(vertices, polygon);
			for (triangle in 0...Std.int(triangles.length / 3)) {
				group.indices.push(mapped[triangles[triangle * 3]]);
				group.indices.push(mapped[triangles[triangle * 3 + (mirrored ? 2 : 1)]]);
				group.indices.push(mapped[triangles[triangle * 3 + (mirrored ? 1 : 2)]]);
			}
			polygon = []; corners = []; polygonIndex++;
		}
		if (polygon.length != 0 || polygonIndex == 0) throw "FBX 多边形没有正确结束或网格为空";
		return groups;
	}

	private function readLayer(object:FbxElement, kind:String, valueName:String, indexName:String, width:Int):FbxLayer {
		var element = layerElement(object, kind);
		if (element == null) return null;
		var count = 0;
		for (entry in object.children) if (entry.name == kind) count++;
		if (count > 1) warn("FBX 只导入首个 Layer 引用的一套 " + kind + " 数据。");
		var values = array(child(element, valueName, true));
		if (values.length % width != 0) throw "FBX 顶点属性分量数量无效";
		var reference = childString(element, "ReferenceInformationType", "Direct"), indices:Array<Float> = [];
		if (reference == "IndexToDirect" || reference == "Index") {
			var entry = child(element, indexName);
			if (entry == null && indexName == "NormalsIndex") entry = child(element, "NormalIndex");
			if (entry == null) throw "FBX 缺少属性索引：" + indexName;
			indices = array(entry);
		}
		else if (reference != "Direct") throw "FBX 顶点属性引用模式不支持";
		return {mapping: childString(element, "MappingInformationType", ""), reference: reference, values: values, indices: indices, width: width};
	}

	/** 按首个 Layer 的 TypedIndex 选择实际属性，不能假设对象声明顺序就是活动 UV。 */
	private static function layerElement(object:FbxElement, kind:String):FbxElement {
		var layer = child(object, "Layer"), wanted = 0, referenced = false, declared = false;
		if (layer != null)
			for (entry in layer.children)
				if (entry.name == "LayerElement" && childString(entry, "Type", "") == kind) {
					if (referenced) throw "FBX 同一 Layer 重复引用同类顶点属性";
					referenced = true; wanted = integer(childNumber(entry, "TypedIndex", 0));
				}
		for (entry in object.children)
			if (entry.name == kind) {
				declared = true;
				if (entry.properties.length > 0 && integer(number(entry.properties[0])) == wanted) return entry;
			}
		if (referenced || declared) throw "FBX Layer 引用的属性定义不存在：" + kind;
		return null;
	}

	private function connections(key:String):Array<FbxConnection> {
		return incoming.exists(key) ? incoming.get(key) : [];
	}

	private static function layerIndex(layer:FbxLayer, vertex:Int, corner:Int, polygon:Int):Int {
		if (layer == null) return -1;
		var index = switch (layer.mapping) {
			case "ByVertice", "ByVertex", "ByControlPoint": vertex;
			case "ByPolygonVertex": corner;
			case "ByPolygon": polygon;
			case "AllSame": 0;
			default: throw "FBX 顶点属性映射模式不支持：" + layer.mapping;
		};
		if (layer.reference != "Direct") {
			if (index >= layer.indices.length) throw "FBX 顶点属性间接索引越界";
			index = integer(layer.indices[index]);
		}
		if (index < 0 || index >= Std.int(layer.values.length / layer.width)) throw "FBX 顶点属性索引越界";
		return index;
	}

	private static function node(name:String, matrix:Array<Float>):ModelNodeData {
		return {name: name, children: [], mesh: -1, skin: -1, matrix: matrix,
			translation: [0.,0.,0.], rotation: [0.,0.,0.,1.], scale: [1.,1.,1.]};
	}

	private static function property(object:FbxElement, key:String):Array<FbxValue> {
		var section = object == null ? null : child(object, "Properties70");
		if (section != null)
			for (entry in section.children)
				if (entry.name == "P" && entry.properties.length >= 4 && string(entry.properties[0]) == key) {
					if (entry.properties.length == 4) throw "FBX 属性缺少值：" + key;
					return entry.properties.slice(4);
				}
		return null;
	}

	private static function vector(object:FbxElement, key:String, fallback:Array<Float>):Array<Float> {
		var values = property(object, key);
		if (values == null) return fallback;
		if (values.length != 3) throw "FBX 向量必须有三个分量：" + key;
		return [for (value in values) number(value)];
	}

	private static function propertyNumber(object:FbxElement, key:String, fallback:Float):Float {
		var values = property(object, key);
		if (values == null) return fallback;
		if (values.length != 1) throw "FBX 标量属性分量无效：" + key;
		return number(values[0]);
	}

	private static function childNumber(object:FbxElement, key:String, fallback:Float):Float {
		var value = child(object, key);
		if (value == null) return fallback;
		if (value.properties.length != 1) throw "FBX 数值字段无效：" + key;
		return number(value.properties[0]);
	}

	private static function childString(object:FbxElement, key:String, fallback:String):String {
		var value = child(object, key);
		if (value == null) return fallback;
		if (value.properties.length != 1) throw "FBX 文本字段无效：" + key;
		return string(value.properties[0]);
	}

	private static function child(object:FbxElement, name:String, required:Bool = false):FbxElement {
		return find(object.children, name, required);
	}

	private static function find(elements:Array<FbxElement>, name:String, required:Bool = false):FbxElement {
		for (element in elements) if (element.name == name) return element;
		if (required) throw "FBX 缺少字段：" + name;
		return null;
	}

	private static function array(element:FbxElement):Array<Float> {
		if (element.properties.length != 1) throw "FBX 数组属性数量无效";
		return switch (element.properties[0]) { case Numbers(values): values; default: throw "FBX 需要数值数组"; };
	}

	private static function number(value:FbxValue):Float {
		var result = switch (value) { case Integer(text): Std.parseFloat(text); case Number(value): value; default: throw "FBX 需要数值属性"; };
		if (!Math.isFinite(result)) throw "FBX 包含非有限数值";
		return result;
	}

	private static function integer(value:Float):Int {
		if (!Math.isFinite(value) || value < -2147483647. || value > 2147483647. || value != Math.floor(value)) throw "FBX 整数超出支持范围";
		return Std.int(value);
	}

	private static function id(value:FbxValue):String {
		return switch (value) {
			case Integer(text): Int64.toStr(Int64.parseString(text));
			default: throw "FBX 对象 ID 必须为整数";
		};
	}

	private static function string(value:FbxValue):String {
		return switch (value) { case Text(value): value; default: throw "FBX 需要文本属性"; };
	}

	private static function name(object:FbxElement):String {
		var value = string(object.properties[1]), zero = value.indexOf("\x00");
		if (zero >= 0) value = value.substr(0, zero);
		return value.split("::").pop();
	}

	private static function unit(value:Float):Float {
		if (!Math.isFinite(value) || value < 0 || value > 1) throw "FBX 基础材质颜色或透明度超出 0～1";
		return value;
	}

	private static function nonzero(values:Array<Float>):Bool {
		for (value in values) if (Math.abs(value) > 1e-8) return true;
		return false;
	}

	private static function colorByte(value:Float):Int {
		return Std.int(Math.round(255 * (value <= 0.0031308 ? value * 12.92 : 1.055 * Math.pow(value, 1 / 2.4) - 0.055)));
	}

	private function warn(message:String):Void { if (warnings.indexOf(message) < 0) warnings.push(message); }
}
