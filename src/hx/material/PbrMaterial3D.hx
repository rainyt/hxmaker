package hx.material;

import hx.display.BitmapData;
import hx.render3d.Math3D;

/** 金属度／粗糙度工作流材质；提供 GGX 直接光照和可选场景 IBL，不包含法线贴图。 */
class PbrMaterial3D extends Material3D {
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
