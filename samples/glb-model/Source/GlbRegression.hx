package;

#if hxmaker_glb_checks
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import hx.assets.GlbAsset;

/** 可选回归入口；使用解析式期望值验证蒙皮空间，不依赖画面是否相似。 */
class GlbRegression {
	private static var checks:Int;
	public static function run(asset:GlbAsset):Void {
		checks = 0;
		expect(asset.nodeCount == 105 && asset.meshCount == 85 && asset.triangleCount == 1330, "输入资产统计");
		var a = asset.createInstance(), b = asset.createInstance();
		try {
			expect(a.meshes.length == 85 && a.triangleCount == 1330, "实例包含全部网格");
			expect(a.meshes[0].geometry != b.meshes[0].geometry && a.meshes[0].material != b.meshes[0].material, "运行时几何与材质独立");
			var untouched = b.meshes[0].getWorldVertices().copy();
			a.animation.play("Idle"); a.update(0.5);
			near(a.animation.time, 0.5, "真实动画时间");
			expect(b.animation.currentName == null, "实例播放状态独立");
			var values = b.meshes[0].getWorldVertices();
			for (i in 0...values.length) near(values[i], untouched[i], "实例顶点不串用");
			a.animation.pause(); a.update(0.25); near(a.animation.time, 0.5, "暂停不推进时间");
			a.animation.resume(); a.update(0.75); near(a.animation.time, 0.25, "非零起点动画循环");
			expect(!a.getBounds().isEmpty(), "模型包围盒非空");
			a.dispose(); expect(!b.isDisposed && b.meshes[0].geometry.positions.length > 0, "销毁实例不破坏另一个实例");
		} catch (error:Dynamic) { a.dispose(); b.dispose(); throw error; }
		a.dispose(); b.dispose();

		var synthetic = GlbAsset.fromBytes(fixture()).createInstance();
		try {
			var mesh = synthetic.meshes[0];
			near(mesh.geometry.positions[0], 1, "两关节各半权重的初始蒙皮");
			near(mesh.geometry.positions[3], 2, "第二顶点初始蒙皮");
			near(synthetic.getBounds().min.x, 1, "忽略蒙皮网格及父级平移");
			synthetic.x = 10; near(mesh.getWorldVertices()[0], 11, "模型外层变换只应用一次");
			synthetic.animation.play("测试", false); synthetic.animation.seek(0.5);
			near(mesh.geometry.positions[0], 1.5, "LINEAR 位移蒙皮");
			near(mesh.geometry.positions[3], 2, "四元数旋转插值后的 X");
			near(mesh.geometry.positions[4], 0.5, "四元数旋转插值后的 Y");
			synthetic.animation.seek(0.25); near(synthetic.getBounds().min.y, 0, "动画重新定位刷新包围盒");
			synthetic.animation.stop(); near(mesh.geometry.positions[0], 1, "停止恢复默认姿态");
		} catch (error:Dynamic) { synthetic.dispose(); throw error; }
		synthetic.dispose();

		var rigid = GlbAsset.fromBytes(fixture("rigid")).createInstance();
		try {
			near(rigid.meshes[0].geometry.positions[0], 0, "刚性路径保留源顶点");
			near(rigid.meshes[0].getWorldVertices()[0], 2, "刚性路径使用关节矩阵");
		} catch (error:Dynamic) { rigid.dispose(); throw error; }
		rigid.dispose();
		var strided = GlbAsset.fromBytes(fixture("stride")).createInstance();
		near(strided.meshes[0].geometry.positions[3], 2, "交错数据按 byteStride 解码"); strided.dispose();
		var step = GlbAsset.fromBytes(fixture("step")).createInstance();
		step.animation.play("测试", false); step.animation.seek(0.5);
		near(step.meshes[0].geometry.positions[0], 1, "STEP 在下一关键帧之前保持前值");
		step.animation.seek(1); near(step.meshes[0].geometry.positions[0], 2, "STEP 到达关键帧时切换值"); step.dispose();
		var inverse = GlbAsset.fromBytes(fixture("inverse")).createInstance();
		near(inverse.meshes[0].geometry.positions[0], 0, "先应用逆绑定矩阵再应用关节变换"); inverse.dispose();
		for (mode in ["bounds", "cycle", "sparse", "extension", "interpolation", "weights", "version"])
			expectFailure(function() { GlbAsset.fromBytes(fixture(mode)); }, "拒绝无效或未支持数据：" + mode);
		trace("HXMAKER_GLB_CHECKS PASS 检查数：" + checks);
	}
	private static function expect(value:Bool, label:String):Void { if (!value) throw "GLB 检查失败：" + label; checks++; }
	private static function near(actual:Float, expected:Float, label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-5, label + "，实际 " + actual + "，预期 " + expected); }
	private static function expectFailure(callback:Void->Void, label:String):Void {
		var failed = false; try { callback(); } catch (_:Dynamic) { failed = true; } expect(failed, label);
	}
	/** 两关节、一个网格；网格父级带额外平移，用来独立验证蒙皮空间。 */
	private static function fixture(mode:String = ""):Bytes {
		var buffer = new BytesBuffer(), views:Array<Dynamic> = [], accessors:Array<Dynamic> = [], offset = 0;
		function add(values:Array<Float>, component:Int, type:String, width:Int, stride:Bool = false):Int {
			var count = Std.int(values.length / width), size = component == 5121 ? 1 : 4, step = stride ? width + 1 : width;
			var bytes = Bytes.alloc(count*step*size);
			for (i in 0...count) for (j in 0...width) {
				if (component == 5121) bytes.set((i*step+j)*size, Std.int(values[i*width+j])); else bytes.setFloat((i*step+j)*size, values[i*width+j]);
			}
			var view:Dynamic = {buffer:0, byteOffset:offset, byteLength:bytes.length};
			if (stride) Reflect.setField(view, "byteStride", step*size);
			views.push(view); buffer.addBytes(bytes, 0, bytes.length); offset += bytes.length;
			while (offset % 4 != 0) { buffer.addByte(0); offset++; }
			accessors.push({bufferView:views.length-1, componentType:component, count:count, type:type}); return accessors.length - 1;
		}
		var position = add([0.,0.,0., 1.,0.,0., 0.,1.,0.], 5126, "VEC3", 3, mode == "stride");
		var joint = add([0.,1.,0.,0., 0.,1.,0.,0., 0.,1.,0.,0.], 5121, "VEC4", 4);
		var w = mode == "rigid" ? [1.,0.,0.,0.] : [0.5,0.5,0.,0.];
		var weight = add(w.concat(w).concat(w), 5126, "VEC4", 4);
		var times = add([0.,1.], 5126, "SCALAR", 1), translation = add([2.,0.,0., 4.,0.,0.], 5126, "VEC3", 3);
		var rotation = add([0.,0.,0.,1., 0.,0.,1.,0.], 5126, "VEC4", 4);
		var skin:Dynamic = {joints:[1,2]};
		if (mode == "inverse") {
			var matrix = [1.,0.,0.,0., 0.,1.,0.,0., 0.,0.,1.,0., -1.,0.,0.,1.];
			Reflect.setField(skin, "inverseBindMatrices", add(matrix.concat(matrix), 5126, "MAT4", 16));
		}
		var raw = buffer.getBytes();
		var nodes:Array<Dynamic> = [{children:[1,2]}, {translation:mode == "rigid" ? [2.,0.,0.] : [0.,0.,0.]},
			{translation:[2.,0.,0.]}, {children:[4], translation:[50.,0.,0.]}, {mesh:0, skin:0, translation:[99.,0.,0.]}];
		var interpolation = mode == "step" ? "STEP" : "LINEAR";
		var samplers:Array<Dynamic> = [{input:times, output:translation, interpolation:interpolation}, {input:times, output:rotation, interpolation:interpolation}];
		var document:Dynamic = {asset:{version:"2.0"}, scene:0, scenes:[{nodes:[0,3]}], nodes:nodes,
			meshes:[{primitives:[{attributes:{POSITION:position, JOINTS_0:joint, WEIGHTS_0:weight}}]}], skins:[skin],
			animations:[{name:"测试", samplers:samplers, channels:[{sampler:0, target:{node:2, path:"translation"}}, {sampler:1, target:{node:1, path:"rotation"}}]}],
			buffers:[{byteLength:raw.length}], bufferViews:views, accessors:accessors};
		switch (mode) {
			case "bounds": Reflect.setField(accessors[0], "byteOffset", 999999);
			case "cycle": Reflect.setField(nodes[1], "children", [0]);
			case "sparse": Reflect.setField(accessors[0], "sparse", {});
			case "extension": Reflect.setField(document, "extensionsRequired", ["KHR_draco_mesh_compression"]);
			case "interpolation": Reflect.setField(samplers[0], "interpolation", "CUBICSPLINE");
			case "weights": raw.setFloat(views[weight].byteOffset, -1);
			default:
		}
		var json = Bytes.ofString(Json.stringify(document)), jsonLength = (json.length + 3) & ~3, binLength = (raw.length + 3) & ~3;
		var result = Bytes.alloc(28 + jsonLength + binLength);
		result.setInt32(0, 0x46546c67); result.setInt32(4, mode == "version" ? 1 : 2); result.setInt32(8, result.length);
		result.setInt32(12, jsonLength); result.setInt32(16, 0x4e4f534a); result.blit(20, json, 0, json.length);
		for (i in json.length...jsonLength) result.set(20+i, 32);
		result.setInt32(20+jsonLength, binLength); result.setInt32(24+jsonLength, 0x004e4942); result.blit(28+jsonLength, raw, 0, raw.length);
		return result;
	}
}
#end
