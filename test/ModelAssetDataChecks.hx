import haxe.crypto.Sha256;
import hx.formats.gltf.GlbImporter;
import hx.formats.gltf.GlbParser;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.model.ModelAssetBuilder;
import hx.model.ModelAssetSchema;
import hx.model.ModelSourceData;
import hx.model.ModelSourceData.ModelNodeData;

/** 中立资产的数值与隔离检查；入口已准备，未经用户安排不执行。 */
class ModelAssetDataChecks {
	private static var checks:Int = 0;

	static function main():Void {
		var source = fixture(), built = ModelAssetBuilder.build(source), primitive = built.meshes[0][0];
		check(built.dataVersion == ModelAssetSchema.DATA_VERSION && built.buildVersion == ModelAssetSchema.BUILD_VERSION, "版本元数据");
		check(built.sceneNodes[0].join(",") == "1,0" && built.sceneNodes[1].join(",") == "2", "父节点优先且场景隔离");
		check(built.parents.join(",") == "1,-1,-1" && built.nodes[0].name == "三角形", "源节点索引保持稳定");
		check(primitive.bounds.join(",") == "0,0,0,1,1,0", "预计算包围盒");
		for (vertex in 0...3) {
			near(primitive.normals[vertex * 3], 0, "生成法线 X");
			near(primitive.normals[vertex * 3 + 1], 0, "生成法线 Y");
			near(primitive.normals[vertex * 3 + 2], 1, "生成法线 Z");
		}
		check(built.stats.vertexCount == 3 && built.stats.triangleCount == 1 && built.stats.generatedNormalCount == 1, "构建统计");
		source.meshes[0][0].positions[0] = 99;
		source.nodes[1].children.resize(0);
		source.materials[0].baseColorFactor[0] = 0;
		check(primitive.positions[0] == 0 && built.nodes[1].children.length == 1
			&& built.materials[0].baseColorFactor[0] == 1, "源数组修改不污染构建结果");
		var degenerate = fixture();
		degenerate.meshes[0][0].indices = [0, 0, 0];
		check(ModelAssetBuilder.build(degenerate).meshes[0][0].normals[1] == 1, "退化面保持原法线回退");
		var rigid = fixture();
		rigid.meshes[0][0].joints = [for (_ in 0...12) 0];
		rigid.meshes[0][0].weights = [0.5,0.,0.,0., 0.5,0.,0.,0., 0.5,0.,0.,0.];
		rigid.skins = [{joints: [1], inverseBindMatrices: [identity()]}];
		rigid.nodes[0].skin = 0;
		var prepared = ModelAssetBuilder.build(rigid);
		check(prepared.meshes[0][0].rigidJoint == 0 && prepared.stats.rigidPrimitiveCount == 1, "权重归一化后识别刚性图元");
		near(prepared.meshes[0][0].weights[0], 1, "归一化权重");
		var animated = fixture();
		animated.animations = [{name: "平移", tracks: [{node: 1, path: "translation", interpolation: "LINEAR",
			times: [0., 1.], values: [2.,0.,0., 4.,0.,0.]}]}];
		var animationData = ModelAssetBuilder.build(animated);
		animated.animations[0].tracks[0].values[0] = 100;
		check(animationData.animations[0].tracks[0].values[0] == 2, "动画数组隔离");
		var times = [0., 1.];
		animated.animations[0].tracks = [
			{node: 0, path: "translation", interpolation: "LINEAR", times: times, values: [0.,0.,0., 1.,0.,0.]},
			{node: 1, path: "translation", interpolation: "LINEAR", times: times, values: [2.,0.,0., 4.,0.,0.]}
		];
		var sharedTimes = ModelAssetBuilder.build(animated).animations[0].tracks;
		check(sharedTimes[0].times == sharedTimes[1].times && sharedTimes[0].times != times, "时间轴复制后保留内部共享");
		fails(source -> { source.nodes[1].children = [0, 0]; }, "重复子节点");
		fails(source -> { source.nodes[0].children = [1]; }, "循环节点");
		fails(source -> { source.scenes[0] = [0]; }, "非根场景节点");
		fails(source -> { source.meshes[0][0].positions[0] = Math.NaN; }, "非有限顶点");
		fails(source -> { source.meshes[0][0].indices[2] = 3; }, "顶点越界");
		fails(source -> { source.meshes[0][0].weights = [1.]; }, "关节权重不配对");
		fails(source -> { source.nodes[0].matrix = [for (_ in 0...16) 0.]; }, "不可逆矩阵");
		fails(source -> { source.nodes[0].scale[0] = 0; }, "零缩放");
		fails(source -> { source.animations = [{name: "错误轨道", tracks: [{node: 0, path: "translation", interpolation: "LINEAR",
			times: [1., 1.], values: [0.,0.,0., 1.,0.,0.]}]}]; }, "非递增动画时间");
		// 以真实 GLB 的原解析结果为对照，确认中立化保持拓扑、统计和动画轨道。
		#if sys
		for (path in ["samples/glb-model/Assets/model.glb", "samples/textured-character/Assets/robot.glb"]) {
			var bytes = sys.io.File.getBytes(path), gltf = GlbParser.parse(bytes), model = GlbImporter.importBytes(bytes);
			check(model.nodes.length == gltf.nodes.length && model.meshes.length == gltf.meshes.length, "真实 GLB 节点和网格数量");
			check(model.animations.length == gltf.animations.length && model.images.length == gltf.images.length, "真实 GLB 动画和图片数量");
			for (i in 0...gltf.meshes.length)
				for (j in 0...gltf.meshes[i].length) {
					var a = gltf.meshes[i][j], b = model.meshes[i][j];
					check(a.indices.join(",") == b.indices.join(","), "真实 GLB 索引不重排");
					check(a.positions.join(",") == b.positions.join(","), "真实 GLB 顶点不量化");
				}
			for (image in model.images)
				check(image.contentHash == Sha256.make(image.bytes).toHex(), "内嵌图片摘要");
		}
		#end
		trace("HXMAKER_MODEL_ASSET_DATA_CHECKS PASS：" + checks);
	}

	/** 父节点索引大于子节点，防止运行时错误地按源索引计算骨架。 */
	public static function fixture():ModelSourceData {
		return {
			sourceFormat: "fixture", nodes: [node("三角形", [], 0, 0), node("父节点", [0], -1, 2), node("其他场景", [], -1, 0)],
			scenes: [[1], [2]], scene: 0,
			meshes: [[{positions: [0.,0.,0., 1.,0.,0., 0.,1.,0.], normals: [], uvs: [0.,0., 1.,0., 0.,1.],
				indices: [0,1,2], joints: [], weights: [], material: 0}]],
			materials: [{name: "基础材质", baseColorFactor: [1.,1.,1.,1.], metallicFactor: 0., roughnessFactor: 1.,
				emissiveFactor: [0.,0.,0.], color: 0xffffff, opacity: 1., alphaMode: AlphaMode3D.OPAQUE,
				alphaCutoff: 0.5, cullMode: CullMode3D.BACK, baseColorTexture: -1}],
			images: [], textures: [], skins: [], animations: [], warnings: []
		};
	}

	public static function identity():Array<Float> return [1.,0.,0.,0., 0.,1.,0.,0., 0.,0.,1.,0., 0.,0.,0.,1.];

	private static function node(name:String, children:Array<Int>, mesh:Int, x:Float):ModelNodeData {
		return {name: name, children: children, mesh: mesh, skin: -1, matrix: null,
			translation: [x,0.,0.], rotation: [0.,0.,0.,1.], scale: [1.,1.,1.]};
	}

	private static function fails(change:ModelSourceData->Void, label:String):Void {
		var source = fixture(), rejected = false;
		change(source);
		try { ModelAssetBuilder.build(source); } catch (_:Dynamic) { rejected = true; }
		check(rejected, "拒绝" + label);
	}

	private static function check(value:Bool, label:String):Void {
		if (!value) throw "模型资产检查失败：" + label;
		checks++;
	}

	private static function near(actual:Float, expected:Float, label:String):Void {
		check(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-6, label);
	}
}
