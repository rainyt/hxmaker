import haxe.Json;
import haxe.io.Bytes;
import hx.formats.gltf.GlbImporter;
import hx.formats.gltf.GlbParser;
import hx.material.Material3D;
import hx.material.PbrMaterial3D;
import hx.material.TextureMinFilter3D;
import hx.model.ModelAssetBuilder;

/** mipmap 采样数据链路检查；需用户安排后手动执行，不代替 GPU 验证。 */
class MipmapChecks {
	static function main():Void {
		for (filter in [9728, 9729, 9984, 9985, 9986, 9987]) {
			var bytes = fixture(filter), parsed = GlbParser.parse(bytes);
			check(parsed.textures[0].minFilter == filter, "GLB 保留完整过滤模式");
			check(parsed.textures[0].minSmoothing == ([9729, 9985, 9987].indexOf(filter) >= 0), "层内过滤兼容值");
			check(parsed.warnings.length == 0, "解析阶段不提前宣告 mipmap 降级");
			var built = ModelAssetBuilder.build(GlbImporter.importBytes(bytes));
			check(built.textures[0].minFilter == filter, "导入和构建后保留 mipmap 模式");
		}
		fails(() -> GlbParser.parse(fixture(0)), "拒绝非法缩小过滤");
		fails(() -> GlbParser.parse(fixture(9987, 9987)), "放大过滤不接受 mipmap 枚举");
		var legacy = GlbImporter.importBytes(fixture(9987));
		legacy.textures[0].minFilter = null;
		legacy.textures[0].minSmoothing = false;
		check(ModelAssetBuilder.build(legacy).textures[0].minFilter == 9728, "旧源数据按布尔过滤读取");
		legacy.textures[0].minFilter = 0;
		fails(() -> ModelAssetBuilder.build(legacy), "构建器拒绝非法过滤");
		var material = new Material3D(), pbr = new PbrMaterial3D();
		material.smoothing = false;
		check(material.textureMinFilter == null && material.textureMinSmoothing == null, "旧材质默认不启用 mipmap");
		var version = material.version;
		material.textureMinFilter = TextureMinFilter3D.LINEAR_MIPMAP_LINEAR;
		check(material.version > version, "完整过滤变更触发重绘");
		fails(() -> material.textureMinFilter = 0, "材质拒绝非法过滤");
		pbr.setMapSampler("normal", false, false, 10497, 33648, TextureMinFilter3D.NEAREST_MIPMAP_LINEAR);
		check(pbr.getUniforms().get("uPbrNormalMapMinFilter")[0] == 9986, "PBR 保留独立 mipmap 配置");
		pbr.setMapSampler("normal", true, false);
		check(pbr.getUniforms().get("uPbrNormalMapMinFilter")[0] == 9728, "旧签名可关闭 mipmap");
		material.dispose(); pbr.dispose();
		trace("HXMAKER_MIPMAP_CHECKS PASS");
	}

	/** 只有 PNG 签名的纯解析夹具，不用于图片解码。 */
	private static function fixture(minFilter:Int, magFilter:Int = 9729):Bytes {
		var raw = Bytes.alloc(8);
		for (i in 0...8) raw.set(i, [137,80,78,71,13,10,26,10][i]);
		var document:Dynamic = {asset:{version:"2.0"}, scene:0, scenes:[{nodes:[]}], nodes:[],
			buffers:[{byteLength:8}], bufferViews:[{buffer:0,byteOffset:0,byteLength:8}],
			images:[{bufferView:0,mimeType:"image/png"}], textures:[{source:0,sampler:0}],
			samplers:[{wrapS:33071,wrapT:33071,minFilter:minFilter,magFilter:magFilter}]};
		var json = Bytes.ofString(Json.stringify(document)), size = (json.length + 3) & ~3;
		var bytes = Bytes.alloc(28 + size + raw.length);
		bytes.setInt32(0, 0x46546c67); bytes.setInt32(4, 2); bytes.setInt32(8, bytes.length);
		bytes.setInt32(12, size); bytes.setInt32(16, 0x4e4f534a); bytes.blit(20, json, 0, json.length);
		for (i in json.length...size) bytes.set(20 + i, 32);
		bytes.setInt32(20 + size, raw.length); bytes.setInt32(24 + size, 0x004e4942); bytes.blit(28 + size, raw, 0, raw.length);
		return bytes;
	}
	private static function check(value:Bool, label:String):Void { if (!value) throw "mipmap 检查失败：" + label; }
	private static function fails(callback:Void->Dynamic, label:String):Void {
		var rejected = false;
		try { callback(); } catch (_:Dynamic) { rejected = true; }
		check(rejected, label);
	}
}
