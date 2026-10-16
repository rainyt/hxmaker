package;

#if hxmaker_character_checks
import haxe.Json;
import haxe.io.Bytes;
import hx.assets.GlbAsset;

/** 可选数值断言：检查图片解码、共享资源、独立实例和解析边界，不替代 GPU 验证。 */
class CharacterChecks {
	private static var checks:Int;
	public static function run(source:GlbAsset):Void {
		checks = 0;
		expect(source.imageCount == 3 && source.textureCount == 3 && source.texturesReady,"三张内嵌图片已解码");
		expect(source.meshCount == 16 && source.triangleCount == 192,"原创角色资源统计");
		expect(source.animationNames.indexOf("Idle") >= 0 && source.animationNames.indexOf("Walk") >= 0,"两个动画片段");
		var nativeBitmap:openfl.display.BitmapData = cast source.getTexture(0).data.getTexture();
		expect(nativeBitmap.width == 128 && nativeBitmap.height == 128,"PNG 解码尺寸");
		expect(nativeBitmap.getPixel(0,0) == 0xff4064,"PNG 左上红色方向标");
		expect(nativeBitmap.getPixel(0,127) == 0x40ffa0,"PNG 左下绿色方向标");
		var a = source.createInstance(-1,{lightingEnabled:true}), b = source.createInstance(-1,{lightingEnabled:true});
		try {
			expect(a.meshes[0].material.texture == source.getTexture(0) && b.meshes[0].material.texture == source.getTexture(0),"两个实例共享资产贴图");
			expect(a.meshes[0].material != b.meshes[0].material && a.meshes[0].geometry != b.meshes[0].geometry,"材质与动态几何独立");
			var initial = a.meshes[0].geometry.positions.copy(), untouched = b.meshes[0].geometry.positions.copy();
			a.animation.play("Walk"); a.animation.seek(0.25);
			var changed = false, values = a.meshes[0].geometry.positions;
			for (i in 0...values.length) if (Math.abs(values[i]-initial[i]) > 1e-5) changed = true;
			expect(changed,"双关节躯干通过通用蒙皮变形");
			for (i in 0...untouched.length) near(b.meshes[0].geometry.positions[i],untouched[i],"另一实例不受动画影响");
			a.meshes[0].material.smoothing = false;
			expect(b.meshes[0].material.smoothing,"采样配置不串实例");
			a.dispose(); expect(b.meshes[0].material.texture.data != null,"销毁一个实例保留共享贴图");
		} catch (error:Dynamic) { a.dispose(); b.dispose(); throw error; }
		a.dispose(); b.dispose();
		var plain = GlbAsset.fromBytes(fixture());
		expect(plain.imageCount == 1 && !plain.texturesReady,"同步解析不冒充已完成图片解码");
		expectFailure(() -> plain.createInstance(),"尚未解码的 GLB 实例化应明确失败");
		for (mode in ["imageBounds","imageUri","mime","signature","textureSource","sampler","wrap","filter","texCoord","transform","missingUV","normalTexture"])
			expectFailure(() -> GlbAsset.fromBytes(fixture(mode)),"拒绝无效或未支持的纹理输入："+mode);
		trace("HXMAKER_CHARACTER_CHECKS PASS 检查数："+checks);
	}
	private static function expect(value:Bool,label:String):Void { if (!value) throw "角色检查失败："+label; checks++; }
	private static function near(actual:Float,expected:Float,label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual-expected)<1e-5,label); }
	private static function expectFailure(callback:Void->Dynamic,label:String):Void {
		var failed = false; try { callback(); } catch (_:Dynamic) { failed = true; } expect(failed,label);
	}
	/** 最小纯解析夹具；PNG 只有签名，实例化必须等真实解码完成。 */
	private static function fixture(mode:String = ""):Bytes {
		var raw = Bytes.alloc(68), positions = [0.,0.,0.,1.,0.,0.,0.,1.,0.], uvs = [0.,1.,1.,1.,0.,0.];
		for (i in 0...positions.length) raw.setFloat(i*4,positions[i]);
		for (i in 0...uvs.length) raw.setFloat(36+i*4,uvs[i]);
		for (i in 0...8) raw.set(60+i,[137,80,78,71,13,10,26,10][i]);
		var image:Dynamic = {bufferView:2,mimeType:"image/png"}, texture:Dynamic = {source:0,sampler:0};
		var info:Dynamic = {index:0}, attributes:Dynamic = {POSITION:0,TEXCOORD_0:1};
		var material:Dynamic = {pbrMetallicRoughness:{baseColorTexture:info}};
		var views:Array<Dynamic> = [{buffer:0,byteOffset:0,byteLength:36},{buffer:0,byteOffset:36,byteLength:24},{buffer:0,byteOffset:60,byteLength:8}];
		var sampler:Dynamic = {wrapS:33071,wrapT:33071,minFilter:9729,magFilter:9729};
		switch (mode) {
			case "imageBounds": views[2].byteLength = 100;
			case "imageUri": image.uri = "external.png";
			case "mime": image.mimeType = "image/webp";
			case "signature": raw.set(60,0);
			case "textureSource": texture.source = 3;
			case "sampler": texture.sampler = 3;
			case "wrap": sampler.wrapS = 0;
			case "filter": sampler.magFilter = 9987;
			case "texCoord": info.texCoord = 1;
			case "transform": info.extensions = {KHR_texture_transform:{offset:[0.5,0.]}};
			case "missingUV": Reflect.deleteField(attributes,"TEXCOORD_0");
			case "normalTexture": material.normalTexture = {index:0};
			default:
		}
		var doc:Dynamic = {asset:{version:"2.0"},scene:0,scenes:[{nodes:[0]}],nodes:[{mesh:0}],
			meshes:[{primitives:[{attributes:attributes,material:0}]}],materials:[material],images:[image],textures:[texture],samplers:[sampler],
			buffers:[{byteLength:raw.length}],bufferViews:views,
			accessors:[{bufferView:0,componentType:5126,count:3,type:"VEC3"},{bufferView:1,componentType:5126,count:3,type:"VEC2"}]};
		var json = Bytes.ofString(Json.stringify(doc)), jsonLength = (json.length+3)&~3;
		var bytes = Bytes.alloc(28+jsonLength+raw.length);
		bytes.setInt32(0,0x46546c67); bytes.setInt32(4,2); bytes.setInt32(8,bytes.length);
		bytes.setInt32(12,jsonLength); bytes.setInt32(16,0x4e4f534a); bytes.blit(20,json,0,json.length);
		for (i in json.length...jsonLength) bytes.set(20+i,32);
		bytes.setInt32(20+jsonLength,raw.length); bytes.setInt32(24+jsonLength,0x004e4942); bytes.blit(28+jsonLength,raw,0,raw.length);
		return bytes;
	}
}
#end
