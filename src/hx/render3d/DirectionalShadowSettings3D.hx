package hx.render3d;

import hx.light.DirectionalLight3D;
import hx.light.ShadowFilter3D;
import hx.light.ShadowQuality3D;

/** 阴影请求的有效配置；不改写灯光上的用户参数，不读取 GPU 状态。 */
class DirectionalShadowSettings3D {
	public var adaptive:Bool;
	public var compactAllowed:Bool;
	public var automaticDistance:Bool;
	public var automaticCascades:Bool;
	public var cascades:Int;
	public var distance:Float;
	public var split:Null<Float>;
	public var blend:Float;
	public var fade:Float;
	public var padding:Float;
	public var filter:ShadowFilter3D;
	public var radius:Float;
	public var normalBias:Float;
	public var automaticBias:Bool;
	public var automaticSlopeBias:Bool;
	public var bias:Float;
	public var slopeBias:Float;
	public var budgetBytes:Int;
	private var explicitSize:Bool;
	private var requestedSize:Int;
	private var quality:ShadowQuality3D;

	public function new(light:DirectionalLight3D) {
		quality = light.shadowQuality; adaptive = quality != ShadowQuality3D.LEGACY;
		automaticDistance = adaptive && !light.hasShadowOverride("shadowDistance");
		automaticCascades = adaptive && !light.hasShadowOverride("shadowCascadeCount");
		compactAllowed = automaticDistance && automaticCascades && light.shadowCascadeSplit == null;
		explicitSize = !adaptive || light.hasShadowOverride("shadowMapSize"); requestedSize = light.shadowMapSize;
		cascades = !automaticCascades ? light.shadowCascadeCount : quality == ShadowQuality3D.PERFORMANCE ? 1 : 2;
		distance = light.shadowDistance; split = light.shadowCascadeSplit;
		blend = light.shadowCascadeBlend; fade = light.shadowFadeRatio;
		padding = !adaptive || light.hasShadowOverride("shadowPadding") ? light.shadowPadding : 0.05;
		filter = !adaptive || light.hasShadowOverride("shadowFilter") ? light.shadowFilter
			: quality == ShadowQuality3D.PERFORMANCE ? ShadowFilter3D.HARD
			: quality == ShadowQuality3D.HIGH ? ShadowFilter3D.PCF9 : ShadowFilter3D.PCF4;
		radius = !adaptive || light.hasShadowOverride("shadowFilterRadius") ? light.shadowFilterRadius : 1.25;
		normalBias = light.shadowNormalBias;
		automaticBias = adaptive && !light.hasShadowOverride("shadowBias");
		automaticSlopeBias = adaptive && !light.hasShadowOverride("shadowSlopeBias");
		bias = light.shadowBias; slopeBias = light.shadowSlopeBias;
		budgetBytes = (quality == ShadowQuality3D.PERFORMANCE ? 8 : quality == ShadowQuality3D.HIGH ? 64 : 32) * 1024 * 1024;
	}

	/** 按总附件预算选择每级尺寸；显式尺寸只接受后端的设备上限与分配降级约束。 */
	public function tileSize(count:Int):Int {
		if (explicitSize) return requestedSize;
		var size = quality == ShadowQuality3D.PERFORMANCE ? 512 : quality == ShadowQuality3D.HIGH || count == 1 ? 2048 : 1024;
		while (size > 16 && size * size * count * 8 > budgetBytes) size = Std.int(size / 2);
		return size;
	}

	/** 偏差先按世界纹素估计，再转换为每级归一化深度；显式值保持原有单位。 */
	public function depthBias(worldTexel:Float, depthRange:Float, bits:Int, slope:Bool):Float {
		if (slope ? !automaticSlopeBias : !automaticBias) return slope ? slopeBias : bias;
		var kernel = filter == ShadowFilter3D.PCF9 ? Math.max(1, radius) : 1.;
		var precision = 2. / (Math.pow(2, bits) - 1);
		return Math.max(precision, worldTexel * (slope ? 0.5 * kernel : 0.02) / Math.max(1e-9, depthRange));
	}
}
