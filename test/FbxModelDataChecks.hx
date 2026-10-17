import haxe.io.Bytes;
import hx.formats.ModelImporter;
import hx.formats.fbx.FbxTriangulator;
import hx.geom.Matrix3D;
import hx.model.ModelAssetData;
import hx.render3d.Math3D;

/** 用户手动执行的数据检查，不依赖 GPU，不自动挂入应用入口。 */
class FbxModelDataChecks {
	private static var count:Int = 0;

	static function main():Void {
		var files = ["robot-ascii.fbx", "robot-binary-7400.fbx", "robot-binary-7500.fbx", "robot.glb"];
		var baseline:Array<Float> = null;
		for (file in files) {
			var data = ModelImporter.importBytes(sys.io.File.getBytes("samples/fbx-model/Assets/" + file));
			check(data.sourceFormat == (StringTools.endsWith(file, ".glb") ? "glb" : "fbx"), "内容识别：" + file);
			check(data.meshes.length == 8 && data.stats.primitiveCount == 14 && data.stats.triangleCount == 78, "已知几何统计：" + file);
			check(data.images.length == 1 && data.textures.length == 1 && data.materials.length == 3, "图片与材质：" + file);
			check(data.nodes.length == 18 && data.skins.length == 0 && data.animations.length == 0, "静态层级：" + file);
			check([for (node in data.nodes) if (node.name == "右臂") node].length == 1, "64 位 ID 不丢失模型节点：" + file);
			var metrics = worldMetrics(data);
			if (baseline == null) baseline = metrics;
			else for (i in 0...metrics.length) near(metrics[i], baseline[i], "世界空间边界和顶点矩与首个 FBX 一致：" + file);
		}
		var text = sys.io.File.getContent("samples/fbx-model/Assets/robot-ascii.fbx");
		fails(Bytes.ofString(StringTools.replace(text, "FBXVersion: 7400", "FBXVersion: 6100")), "7.x");
		fails(Bytes.ofString(~/Objects:\s*\{/.replace(text, 'Objects: {\nDeformer: 42, "Deformer::不支持的蒙皮", "Skin" {}\n')), "骨骼");
		fails(Bytes.ofString("不是模型文件"), "无法识别");
		var corrupted = sys.io.File.getBytes("samples/fbx-model/Assets/robot-binary-7500.fbx");
		corrupted.setInt32(31, 1);
		fails(corrupted, "64 位偏移");
		var vertices = [0.,0.,0., 2.,0.,0., 2.,2.,0., 1.,1.,0., 0.,2.,0.];
		check(FbxTriangulator.triangulate(vertices, [0,1,2,3,4]).length == 9, "凹多边形生成三个三角形");
		trace("HXMAKER_FBX_MODEL_DATA_CHECKS PASS：" + count);
	}

	/** 独立逐点变换核对轴向、米制换算、层级和枢轴，不只比较文件是否可解析。 */
	private static function worldMetrics(data:ModelAssetData):Array<Float> {
		var globals:Array<Matrix3D> = [for (_ in data.nodes) null];
		var result = [Math.POSITIVE_INFINITY,Math.POSITIVE_INFINITY,Math.POSITIVE_INFINITY,
			Math.NEGATIVE_INFINITY,Math.NEGATIVE_INFINITY,Math.NEGATIVE_INFINITY,0.,0.,0.];
		for (index in data.sceneNodes[0]) {
			var node = data.nodes[index], parent = data.parents[index];
			var local = node.matrix == null ? Math3D.fromTRS(node.translation,node.rotation,node.scale) : new Matrix3D(node.matrix);
			globals[index] = parent < 0 ? local : Math3D.multiply(globals[parent],local);
			if (node.mesh < 0) continue;
			for (primitive in data.meshes[node.mesh]) {
				var output:Array<Float> = [];
				globals[index].transformVectors(primitive.positions, output);
				for (vertex in 0...Std.int(output.length / 3))
					for (axis in 0...3) {
						var value = output[vertex * 3 + axis];
						result[axis] = Math.min(result[axis],value);
						result[axis + 3] = Math.max(result[axis + 3],value);
						result[axis + 6] += value;
					}
			}
		}
		return result;
	}

	private static function fails(bytes:Bytes, expected:String):Void {
		var message = "";
		try { ModelImporter.importBytes(bytes); } catch (error:Dynamic) { message = Std.string(error); }
		check(message.indexOf(expected) >= 0, "错误诊断包含：" + expected);
	}

	private static function check(value:Bool, message:String):Void {
		if (!value) throw "FBX 数据检查失败：" + message;
		count++;
	}

	private static function near(actual:Float, expected:Float, message:String):Void {
		check(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-4, message);
	}
}
