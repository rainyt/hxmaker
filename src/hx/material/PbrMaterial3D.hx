package hx.material;

import hx.display.BitmapData;
import hx.render3d.Math3D;

/** 金属度／粗糙度工作流材质，支持 PBR 贴图、GGX 直接光照和可选场景 IBL。 */
class PbrMaterial3D extends Material3D {
	private var __metallicRoughnessTexture:BitmapData;
	private var __normalTexture:BitmapData;
	private var __occlusionTexture:BitmapData;
	private var __emissiveTexture:BitmapData;
	private var __normalScale:Float = 1;
	private var __occlusionStrength:Float = 1;

	/** 线性数据贴图，G 为粗糙度，B 为金属度，与对应因子相乘。 */
	public var metallicRoughnessTexture(get, set):BitmapData;
	private function get_metallicRoughnessTexture():BitmapData { return __metallicRoughnessTexture; }
	private function set_metallicRoughnessTexture(value:BitmapData):BitmapData {
		ensureMutable(); __metallicRoughnessTexture = value; bindMap("metallicRoughness", value); return value;
	}
	/** 切线空间法线，按线性 RGB 解码为 XYZ，采用 glTF 的 +Y 约定。 */
	public var normalTexture(get, set):BitmapData;
	private function get_normalTexture():BitmapData { return __normalTexture; }
	private function set_normalTexture(value:BitmapData):BitmapData {
		ensureMutable(); __normalTexture = value; bindMap("normal", value); return value;
	}
	/** 线性 R 通道环境遮蔽，只衰减间接光。 */
	public var occlusionTexture(get, set):BitmapData;
	private function get_occlusionTexture():BitmapData { return __occlusionTexture; }
	private function set_occlusionTexture(value:BitmapData):BitmapData {
		ensureMutable(); __occlusionTexture = value; bindMap("occlusion", value); return value;
	}
	/** sRGB 自发光 RGB，与 emissive 线性因子相乘，不影响不透明度。 */
	public var emissiveTexture(get, set):BitmapData;
	private function get_emissiveTexture():BitmapData { return __emissiveTexture; }
	private function set_emissiveTexture(value:BitmapData):BitmapData {
		ensureMutable(); __emissiveTexture = value; bindMap("emissive", value); return value;
	}
	/** 法线贴图 XY 系数，默认 1，允许有限负值以配合特殊资产。 */
	public var normalScale(get, set):Float;
	private function get_normalScale():Float { return __normalScale; }
	private function set_normalScale(value:Float):Float {
		if (!Math3D.finite(value)) throw "法线贴图系数必须为有限值";
		ensureMutable(); __normalScale = value; setUniform("uPbrNormalScale", [value]); return value;
	}
	/** AO 强度，范围 0～1，0 表示不遮蔽间接光。 */
	public var occlusionStrength(get, set):Float;
	private function get_occlusionStrength():Float { return __occlusionStrength; }
	private function set_occlusionStrength(value:Float):Float {
		unit(value, "AO 强度");
		ensureMutable(); __occlusionStrength = value; setUniform("uPbrOcclusionStrength", [value]); return value;
	}

	/** 每张贴图独立配置采样；名称为 metallicRoughness、normal、occlusion 或 emissive。 */
	public function setMapSampler(map:String, smoothing:Bool = true, minSmoothing:Bool = true,
		wrapU:TextureWrap3D = TextureWrap3D.CLAMP, wrapV:TextureWrap3D = TextureWrap3D.CLAMP, minFilter:Null<Int> = null):Void {
		ensureMutable();
		if ([33071, 10497, 33648].indexOf(wrapU) < 0 || [33071, 10497, 33648].indexOf(wrapV) < 0)
			throw "PBR 贴图包裹模式无效";
		var filter = TextureMinFilter3D.resolve(minFilter, minSmoothing);
		TextureMinFilter3D.validate(filter);
		setUniform(mapName(map) + "MinFilter", [filter * 1.]);
		setUniform(mapName(map) + "Sampler", [smoothing ? 1. : 0., minSmoothing ? 1. : 0., wrapU, wrapV]);
	}
	private function bindMap(map:String, bitmap:BitmapData):Void {
		var name = mapName(map);
		if (bitmap == null) removeTextureUniform(name); else setTextureUniform(name, bitmap);
	}
	private static function mapName(map:String):String {
		return switch (map) {
			case "metallicRoughness": "uPbrMetallicRoughnessMap";
			case "normal": "uPbrNormalMap";
			case "occlusion": "uPbrOcclusionMap";
			case "emissive": "uPbrEmissiveMap";
			default: throw "PBR 贴图类型无效：" + map;
		};
	}
	override private function get_pbrMapMask():Int {
		return (__metallicRoughnessTexture == null ? 0 : 1) | (__normalTexture == null ? 0 : 2)
			| (__occlusionTexture == null ? 0 : 4) | (__emissiveTexture == null ? 0 : 8);
	}

	private var __metallic:Float = 0;
	private var __roughness:Float = 0.5;
	private var __emissive:Array<Float> = [0., 0., 0.];
	private var __baseColorFactor:Array<Float> = [1., 1., 1.];
	private var __exposure:Float = 1;
	private var __toneMapping:Bool = true;

	/** 金属度，范围 0～1；普通皮肤、塑料与布料使用 0。 */
	public var metallic(get, set):Float;
	private function get_metallic():Float { return __metallic; }
	private function set_metallic(value:Float):Float {
		unit(value, "金属度");
		ensureMutable();
		__metallic = value;
		setUniform("uPbrMetallic", [value]);
		return value;
	}

	/** 感知粗糙度，范围 0～1；着色下限为 0.045，低精度设备为 0.1，避免镜面奇点。 */
	public var roughness(get, set):Float;
	private function get_roughness():Float { return __roughness; }
	private function set_roughness(value:Float):Float {
		unit(value, "粗糙度");
		ensureMutable();
		__roughness = value;
		setUniform("uPbrRoughness", [value]);
		return value;
	}

	/** 线性 RGB 基础色因子，与显示空间的 color 和基础纹理共同相乘；返回副本。 */
	public var baseColorFactor(get, set):Array<Float>;
	private function get_baseColorFactor():Array<Float> { return __baseColorFactor.copy(); }
	private function set_baseColorFactor(value:Array<Float>):Array<Float> {
		validateColor(value, "基础颜色", true);
		ensureMutable();
		__baseColorFactor = value.copy();
		setUniform("uPbrBaseColor", value);
		return value;
	}

	/** 线性 RGB 自发光，可大于 1；不受场景灯光和阴影影响，返回副本。 */
	public var emissive(get, set):Array<Float>;
	private function get_emissive():Array<Float> { return __emissive.copy(); }
	private function set_emissive(value:Array<Float>):Array<Float> {
		validateColor(value, "自发光", false);
		ensureMutable();
		__emissive = value.copy();
		setUniform("uPbrEmissive", value);
		return value;
	}

	/** 色调映射前的非负曝光倍率，默认 1。 */
	public var exposure(get, set):Float;
	private function get_exposure():Float { return __exposure; }
	private function set_exposure(value:Float):Float {
		if (!Math3D.finite(value) || value < 0) throw "PBR 曝光必须为非负有限值";
		ensureMutable();
		__exposure = value;
		setUniform("uPbrExposure", [value]);
		return value;
	}

	/** 是否在输出前使用 Reinhard 色调映射，默认开启；当前离屏目标仍为 LDR。 */
	public var toneMapping(get, set):Bool;
	private function get_toneMapping():Bool { return __toneMapping; }
	private function set_toneMapping(value:Bool):Bool {
		ensureMutable();
		__toneMapping = value;
		setUniform("uPbrToneMapping", [value ? 1. : 0.]);
		return value;
	}

	override private function get_pbrEnabled():Bool { return true; }

	/** 贴图为借用引用；默认非金属、中等粗糙度，启用光照和线性基础色计算。 */
	public function new(texture:BitmapData = null, color:Int = 0xffffff, metallic:Float = 0, roughness:Float = 0.5) {
		super();
		this.texture = texture;
		this.color = color;
		lightingEnabled = true;
		colorMultiplyLinear = true;
		this.metallic = metallic;
		this.roughness = roughness;
		baseColorFactor = __baseColorFactor;
		emissive = __emissive;
		exposure = __exposure;
		toneMapping = __toneMapping;
		normalScale = __normalScale;
		occlusionStrength = __occlusionStrength;
		for (map in ["metallicRoughness", "normal", "occlusion", "emissive"]) setMapSampler(map);
	}

	override public function dispose():Void {
		super.dispose();
		__metallicRoughnessTexture = __normalTexture = __occlusionTexture = __emissiveTexture = null;
	}

	private function ensureMutable():Void {
		if (isDisposed) throw "材质已经销毁";
	}

	private static function unit(value:Float, name:String):Void {
		if (!Math3D.finite(value) || value < 0 || value > 1) throw "PBR " + name + "必须介于 0 和 1";
	}
	private static function validateColor(value:Array<Float>, name:String, bounded:Bool):Void {
		if (value == null || value.length != 3) throw "PBR " + name + "必须为 RGB 三分量";
		for (component in value)
			if (!Math3D.finite(component) || component < 0 || (bounded && component > 1))
				throw "PBR " + name + "分量无效";
	}
}
