import hx.animation3d.Skin3D;
import hx.display3d.MeshObject;
import hx.formats.gltf.GlbImporter;
import hx.geom.Matrix3D;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.material.PbrMaterial3D;
import hx.model.ModelAssetBuilder;
import hx.render3d.Math3D;

/** PBR 数据贴图和切线链路检查；仅提供手动入口，本轮不执行。 */
class PbrTextureChecks {
	public static function run():Void {
		// 旧导入器和业务自建资产无需立即补齐新增可选字段。
		var legacy = ModelAssetBuilder.build(ModelAssetDataChecks.fixture());
		check(legacy.materials[0].normalTexture == -1 && legacy.materials[0].metallicRoughnessTexture == -1, "旧源数据兼容");
		check(legacy.materials[0].normalScale == 1 && legacy.materials[0].occlusionStrength == 1, "贴图系数缺省值");
		var source = ModelAssetDataChecks.fixture();
		source.meshes[0][0].tangents = [1.,0.,0.,1., 1.,0.,0.,1., 1.,0.,0.,1.];
		var built = ModelAssetBuilder.build(source);
		source.meshes[0][0].tangents[0] = 0;
		near(built.meshes[0][0].tangents[0], 1, "源切线复制隔离");
		var plane = PlaneGeometry.create(), material = new PbrMaterial3D(), mesh = new MeshObject(plane, material);
		try {
			near(plane.getTangents()[0], 1, "平面 UV 对应正 X 切线");
			near(plane.getTangents()[3], -1, "平面 UV 的负手性");
			mesh.scaleX = -2;
			near(mesh.getWorldTangents()[0], -1, "镜像非均匀缩放变换切线方向");
			near(mesh.getWorldTangents()[3], 1, "镜像翻转切线手性");
			var before = plane.getTangents(); plane.uvs[0] = 0.25; plane.invalidate();
			check(plane.getTangents() != before, "UV 修改使自动切线失效");
		} catch (error:Dynamic) { mesh.dispose(); plane.dispose(); material.dispose(); throw error; }
		mesh.dispose(); plane.dispose(); material.dispose();
		// 混合两个关节矩阵后，切线使用线性变换，法线使用逆转置。
		var skinSource = ModelAssetDataChecks.fixture();
		skinSource.meshes[0][0].joints = [0,1,0,0, 0,1,0,0, 0,1,0,0];
		skinSource.meshes[0][0].weights = [0.5,0.5,0.,0., 0.5,0.5,0.,0., 0.5,0.5,0.,0.];
		skinSource.meshes[0][0].tangents = [1.,0.,0.,1., 1.,0.,0.,1., 1.,0.,0.,1.];
		var primitive = ModelAssetBuilder.build(skinSource).meshes[0][0];
		var geometry = new Geometry3D(primitive.positions, primitive.uvs, primitive.indices, primitive.normals, primitive.tangents);
		material = new PbrMaterial3D(); mesh = new MeshObject(geometry, material);
		var skin = new Skin3D({joints:[0,1], inverseBindMatrices:[ModelAssetDataChecks.identity(), ModelAssetDataChecks.identity()]});
		try {
			skin.bind(mesh, primitive);
			skin.update([new Matrix3D(), Math3D.compose(0,0,0,0,0,90,1,1,1)]);
			near(geometry.tangents[0], Math.sqrt(0.5), "CPU 蒙皮切线 X");
			near(geometry.tangents[1], Math.sqrt(0.5), "CPU 蒙皮切线 Y");
			near(geometry.normals[2], 1, "CPU 蒙皮法线与切线正交");
		} catch (error:Dynamic) { skin.dispose(); mesh.dispose(); geometry.dispose(); material.dispose(); throw error; }
		skin.dispose(); mesh.dispose(); geometry.dispose(); material.dispose();
		#if sys
		var data = GlbImporter.importBytes(sys.io.File.getBytes("samples/3d/pbr-material/Assets/pbr/material-sphere.glb"));
		var imported = data.materials[0];
		check(imported.baseColorTexture == 0 && imported.metallicRoughnessTexture == 1 && imported.normalTexture == 2
			&& imported.occlusionTexture == 3 && imported.emissiveTexture == 4, "真实内嵌 GLB 的五类贴图语义");
		check(data.images.length == 5 && data.meshes[0][0].tangents.length == Std.int(data.meshes[0][0].positions.length / 3) * 4,
			"真实 GLB 的图片与显式切线链路");
		#end
		trace("HXMAKER_PBR_TEXTURE_CHECKS PASS");
	}
	private static function check(value:Bool, label:String):Void {
		if (!value) throw "PBR 贴图检查失败：" + label;
	}
	private static function near(actual:Float, expected:Float, label:String):Void {
		check(Math.isFinite(actual) && Math.abs(actual - expected) < 1e-6, label);
	}
}
