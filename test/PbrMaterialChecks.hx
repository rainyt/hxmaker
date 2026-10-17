import hx.assets.ModelAsset;
import hx.events.Event;
import hx.material.PbrMaterial3D;
import hx.material.LambertTextureMaterial;
import hx.material.UnlitTextureMaterial;
import hx.render3d.openfl.MeshBatch3D;

/** PBR 模型接入、实例隔离和批次兼容检查；需在配置依赖的环境手动调用，尚未执行。 */
class PbrMaterialChecks {
	public static function run():Void {
		var source = ModelAssetDataChecks.fixture();
		source.materials[0].baseColorFactor = [0.123456, 0.4, 0.8, 0.6];
		source.materials[0].opacity = 0.6;
		source.materials[0].metallicFactor = 0.8;
		source.materials[0].roughnessFactor = 0.3;
		source.materials[0].emissiveFactor = [0.1, 0.2, 0.3];
		var asset = ModelAsset.fromSource(source);
		var unlit = asset.createInstance();
		var lambert = asset.createInstance(-1, {lightingEnabled:true});
		var first = asset.createInstance(-1, {pbrEnabled:true, lightingEnabled:false});
		var second = asset.createInstance(-1, {pbrEnabled:true});
		try {
			check(Std.isOfType(unlit.meshes[0].material, UnlitTextureMaterial), "旧调用保持无光照");
			check(Std.isOfType(lambert.meshes[0].material, LambertTextureMaterial), "基础光照保持 Lambert");
			check(Std.isOfType(first.meshes[0].material, PbrMaterial3D), "PBR 选项优先于基础光照选项");
			var a:PbrMaterial3D = cast first.meshes[0].material, b:PbrMaterial3D = cast second.meshes[0].material;
			check(a.lightingEnabled && a.pbrEnabled, "导入模型启用 PBR 光照");
			near(a.baseColorFactor[0], 0.123456, "线性基础色不经过整数颜色量化");
			near(a.metallic, 0.8, "源金属度传递"); near(a.roughness, 0.3, "源粗糙度传递");
			near(a.emissive[2], 0.3, "源自发光传递"); near(a.opacity, 0.6, "源不透明度传递");
			check(MeshBatch3D.materialKey(a, false) == MeshBatch3D.materialKey(b, false), "同参数 PBR 可兼容合批");
			var observed:Float = -1;
			a.addEventListener(Event.CHANGE, _ -> { observed = a.roughness; });
			a.roughness = 0.7;
			near(observed, 0.7, "变更监听读取新材质状态");
			near(b.roughness, 0.3, "材质修改不污染另一个模型实例");
			check(MeshBatch3D.materialKey(a, false) != MeshBatch3D.materialKey(b, false), "不同 PBR 参数拆批");
			check(MeshBatch3D.materialKey(a, false) != MeshBatch3D.materialKey(lambert.meshes[0].material, false), "PBR 与 Lambert 拆批");
			var factor = a.baseColorFactor; factor[0] = 1;
			near(a.baseColorFactor[0], 0.123456, "基础色数组读取隔离");
			var emission = [0.4, 0.5, 0.6]; a.emissive = emission; emission[0] = 1;
			near(a.emissive[0], 0.4, "自发光数组写入隔离");
			var mesh = first.meshes[0], snapshot = first.meshes[0].geometry;
			first.dispose();
			check(a.isDisposed && snapshot.isDisposed && mesh.material == null, "模型销毁释放实例拥有的 PBR 资源");
			check(!b.isDisposed, "销毁不污染其他实例");
		} catch (error:Dynamic) {
			unlit.dispose(); lambert.dispose(); first.dispose(); second.dispose(); throw error;
		}
		unlit.dispose(); lambert.dispose(); first.dispose(); second.dispose();
		// glTF 中没有显式材质的图元也必须使用 glTF 默认金属度和粗糙度。
		var implicit = ModelAssetDataChecks.fixture();
		implicit.sourceFormat = "glb"; implicit.meshes[0][0].material = -1;
		var model = ModelAsset.fromSource(implicit).createInstance(-1, {pbrEnabled:true});
		try {
			var material:PbrMaterial3D = cast model.meshes[0].material;
			near(material.metallic, 1, "glTF 隐式默认金属度"); near(material.roughness, 1, "glTF 隐式默认粗糙度");
		} catch (error:Dynamic) { model.dispose(); throw error; }
		model.dispose();
		trace("HXMAKER_PBR_MATERIAL_CHECKS PASS");
	}

	private static function check(value:Bool, label:String):Void {
		if (!value) throw "PBR 检查失败：" + label;
	}
	private static function near(actual:Float, expected:Float, label:String):Void {
		check(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-6, label);
	}
}
