import hx.assets.ModelAsset;
import hx.assets.GlbAsset;
import hx.assets.Assets;
import hx.events.Event;

/** 在已配置 hxmaker 依赖的项目中手动调用 run；本次只提供入口，不执行。 */
class ModelAssetRuntimeChecks {
	public static function run():Void {
		var source = ModelAssetDataChecks.fixture(), asset = ModelAsset.fromSource(source);
		var a = asset.createInstance(), b = asset.createInstance();
		try {
			check(a.meshes[0].geometry != b.meshes[0].geometry && a.meshes[0].material != b.meshes[0].material, "实例几何与材质隔离");
			check(a.getNodeIndex(a.findNodes("三角形")[0]) == 0 && a.getNodeByIndex(2) == null, "节点索引与场景隔离");
			near(a.meshes[0].getWorldVertices()[0], 2, "父节点索引大于子节点时的层级变换");
			near(a.meshes[0].geometry.bounds.max.y, 1, "实例采用预计算局部包围盒");
			var geometry = a.meshes[0].geometry, events = 0;
			geometry.addEventListener(Event.CHANGE, _ -> { events++; });
			geometry.positions[7] = -1;
			geometry.invalidate();
			near(geometry.getNormals()[2], -1, "实例修改后自动法线仍失效");
			near(b.meshes[0].geometry.normals[2], 1, "修改一个实例不影响另一个");
			check(events == 1, "业务修改仍派发几何变更事件");
			var stats = asset.buildStats;
			stats.triangleCount = 99;
			check(asset.triangleCount == 1, "构建统计副本隔离");
			a.dispose();
			check(!b.isDisposed && b.meshes[0].geometry.positions.length == 9, "释放隔离");
		} catch (error:Dynamic) { a.dispose(); b.dispose(); throw error; }
		a.dispose(); b.dispose();
		var animated = ModelAssetDataChecks.fixture();
		animated.meshes[0][0].joints = [for (_ in 0...12) 0];
		animated.meshes[0][0].weights = [1.,0.,0.,0., 1.,0.,0.,0., 1.,0.,0.,0.];
		animated.nodes[0].skin = 0;
		animated.skins = [{joints: [1], inverseBindMatrices: [ModelAssetDataChecks.identity()]}];
		animated.animations = [{name: "移动", tracks: [{node: 1, path: "translation", interpolation: "LINEAR",
			times: [0.,1.], values: [2.,0.,0., 4.,0.,0.]}]}];
		var model = ModelAsset.fromSource(animated).createInstance();
		try {
			var socket = model.createSocket(1, "挂点");
			model.animation.play("移动", false);
			model.animation.seek(0.5);
			near(model.meshes[0].getWorldVertices()[0], 3, "父节点优先的刚性蒙皮动画");
			near(socket.getWorldMatrix().rawData[12], 3, "动画挂点跟随");
			model.animation.stop();
			near(model.meshes[0].getWorldVertices()[0], 2, "停止恢复共享初始姿态");
		} catch (error:Dynamic) { model.dispose(); throw error; }
		model.dispose();
		// 多关节路径必须保留实例输出法线，不能因 invalidate 而清空。
		animated.skins[0] = {joints: [1, 0], inverseBindMatrices: [ModelAssetDataChecks.identity(), ModelAssetDataChecks.identity()]};
		animated.meshes[0][0].joints = [0,1,0,0, 0,1,0,0, 0,1,0,0];
		animated.meshes[0][0].weights = [0.5,0.5,0.,0., 0.5,0.5,0.,0., 0.5,0.5,0.,0.];
		var cpu = ModelAsset.fromSource(animated).createInstance();
		try {
			near(cpu.meshes[0].geometry.positions[0], 2, "多权重蒙皮初始空间");
			cpu.animation.play("移动", false);
			cpu.animation.seek(0.5);
			near(cpu.meshes[0].geometry.positions[0], 3, "多权重蒙皮动画");
			near(cpu.meshes[0].geometry.normals[2], 1, "多权重蒙皮法线保留");
			near(cpu.meshes[0].geometry.bounds.min.x, 3, "多权重蒙皮动态包围盒");
		} catch (error:Dynamic) { cpu.dispose(); throw error; }
		cpu.dispose();
		// 原有模型入口和统一资产类型保持可赋值关系。
		var compatibility = new Assets();
		compatibility.objects.set("fixture", asset);
		check(compatibility.getModel("fixture") == asset, "统一 Assets 取值入口");
		trace("HXMAKER_MODEL_ASSET_RUNTIME_CHECKS PASS");
	}

	/** 可用于已加载且图片就绪的 GLB，检查兼容入口和独立实例。 */
	public static function checkGlb(asset:GlbAsset):Void {
		var assets = new Assets();
		assets.objects.set("fixture", asset);
		check(assets.getModel("fixture") == asset && assets.getGlb("fixture") == asset, "GLB 兼容取值");
		var model = assets.getModel("fixture").createInstance();
		model.dispose();
	}

	private static function check(value:Bool, label:String):Void {
		if (!value) throw "模型运行时检查失败：" + label;
	}

	private static function near(actual:Float, expected:Float, label:String):Void {
		check(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-6, label);
	}
}
