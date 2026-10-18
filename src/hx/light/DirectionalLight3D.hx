package hx.light;

import hx.geom.Bounds3D;
import hx.render3d.Math3D;

/** 方向表示光传播方向；可注册为普通方向光，或通过 Scene3D.light 指定为带阴影的主光。 */
class DirectionalLight3D extends Light3D {
	private var __shadowOverrides:Map<String, Bool> = [];
	private var __shadowQuality:ShadowQuality3D = ShadowQuality3D.BALANCED;

	/** 可选质量档位，默认均衡；LEGACY 沿用旧取景与偏差。显式参数始终优先。 */
	public var shadowQuality(get, set):ShadowQuality3D;
	private function get_shadowQuality():ShadowQuality3D { return __shadowQuality; }
	private function set_shadowQuality(value:ShadowQuality3D):ShadowQuality3D {
		if (__shadowQuality != value) { __shadowQuality = value; invalidate(); }
		return value;
	}

	/** 判断参数是否由业务显式设置，不根据数值是否等于默认值推断。 */
	public function hasShadowOverride(name:String):Bool { return __shadowOverrides.exists(name); }

	/** 恢复指定参数的自动配置；省略名称时清除全部覆盖和手动范围，保留质量档位。 */
	public function resetShadowOverrides(name:String = null):Void {
		if (name != null) {
			switch (name) {
				case "shadowMapSize": __shadowMapSize = 1024;
				case "shadowBias": __shadowBias = 0.0001;
				case "shadowSlopeBias": __shadowSlopeBias = 0.0005;
				case "shadowPadding": __shadowPadding = 0.1;
				case "shadowDistance": __shadowDistance = 100;
				case "shadowCascadeCount": __shadowCascadeCount = 2;
				case "shadowCascadeSplit": __shadowCascadeSplit = null;
				case "shadowCascadeBlend": __shadowCascadeBlend = 0.15;
				case "shadowFadeRatio": __shadowFadeRatio = 0.1;
				case "shadowNormalBias": __shadowNormalBias = 0.5;
				case "shadowFilter": __shadowFilter = ShadowFilter3D.PCF4;
				case "shadowFilterRadius": __shadowFilterRadius = 1.5;
				case "shadowBounds": shadowBounds = null;
				default: throw "阴影覆盖参数名称无效：" + name;
			}
			__shadowOverrides.remove(name);
		} else {
			__shadowMapSize = 1024;
			__shadowBias = 0.0001;
			__shadowSlopeBias = 0.0005;
			__shadowPadding = 0.1;
			__shadowDistance = 100;
			__shadowCascadeCount = 2;
			__shadowCascadeSplit = null;
			__shadowCascadeBlend = 0.15;
			__shadowFadeRatio = 0.1;
			__shadowNormalBias = 0.5;
			__shadowFilter = ShadowFilter3D.PCF4;
			__shadowFilterRadius = 1.5;
			__shadowOverrides.clear(); shadowBounds = null;
		}
		invalidate();
	}

	/** 是否请求阴影，默认关闭，实际支持结果见场景统计。 */
	public var shadowEnabled:Bool = false;

	/** 显式每级边长，允许 16～8192 的二次幂；未覆盖时按档位和级联预算选择，读取请求默认值 1024。 */
	public var shadowMapSize(get, set):Int;
	private var __shadowMapSize:Int = 1024;
	private function get_shadowMapSize():Int { return __shadowMapSize; }
	private function set_shadowMapSize(value:Int):Int {
		var changed = !hasShadowOverride("shadowMapSize") || __shadowMapSize != value;
		__shadowMapSize = value; __shadowOverrides.set("shadowMapSize", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式归一化深度偏差，必须非负有限；未覆盖时自动计算，读取请求默认值 0.0001。 */
	public var shadowBias(get, set):Float;
	private var __shadowBias:Float = 0.0001;
	private function get_shadowBias():Float { return __shadowBias; }
	private function set_shadowBias(value:Float):Float {
		var changed = !hasShadowOverride("shadowBias") || __shadowBias != value;
		__shadowBias = value; __shadowOverrides.set("shadowBias", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式归一化斜率偏差，必须非负有限；未覆盖时自动计算，读取请求默认值 0.0005。 */
	public var shadowSlopeBias(get, set):Float;
	private var __shadowSlopeBias:Float = 0.0005;
	private function get_shadowSlopeBias():Float { return __shadowSlopeBias; }
	private function set_shadowSlopeBias(value:Float):Float {
		var changed = !hasShadowOverride("shadowSlopeBias") || __shadowSlopeBias != value;
		__shadowSlopeBias = value; __shadowOverrides.set("shadowSlopeBias", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式非负留边比例；自动档使用 0.05，传统档及请求默认值为 0.1。 */
	public var shadowPadding(get, set):Float;
	private var __shadowPadding:Float = 0.1;
	private function get_shadowPadding():Float { return __shadowPadding; }
	private function set_shadowPadding(value:Float):Float {
		var changed = !hasShadowOverride("shadowPadding") || __shadowPadding != value;
		__shadowPadding = value; __shadowOverrides.set("shadowPadding", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式相机前向覆盖距离；0 沿用 camera.far。未覆盖时自动规划，传统档及请求默认值为 100。 */
	public var shadowDistance(get, set):Float;
	private var __shadowDistance:Float = 100;
	private function get_shadowDistance():Float { return __shadowDistance; }
	private function set_shadowDistance(value:Float):Float {
		var changed = !hasShadowOverride("shadowDistance") || __shadowDistance != value;
		__shadowDistance = value; __shadowOverrides.set("shadowDistance", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式级联数量，允许 1 或 2；未覆盖时自动选择，请求默认值为 2；手动世界范围使用单级。 */
	public var shadowCascadeCount(get, set):Int;
	private var __shadowCascadeCount:Int = 2;
	private function get_shadowCascadeCount():Int { return __shadowCascadeCount; }
	private function set_shadowCascadeCount(value:Int):Int {
		var changed = !hasShadowOverride("shadowCascadeCount") || __shadowCascadeCount != value;
		__shadowCascadeCount = value; __shadowOverrides.set("shadowCascadeCount", true);
		if (changed) invalidate();
		return value;
	}

	/** 可选近级联深度占比，范围 (0,1)；null 沿用均匀与对数混合切分。 */
	public var shadowCascadeSplit(get, set):Null<Float>;
	private var __shadowCascadeSplit:Null<Float> = null;
	private function get_shadowCascadeSplit():Null<Float> { return __shadowCascadeSplit; }
	private function set_shadowCascadeSplit(value:Null<Float>):Null<Float> {
		var changed = !hasShadowOverride("shadowCascadeSplit") || __shadowCascadeSplit != value;
		__shadowCascadeSplit = value; __shadowOverrides.set("shadowCascadeSplit", true);
		if (changed) invalidate();
		return value;
	}

	/** 两级交界混合占近级联跨度的比例，范围 0～0.5，默认 0.15；0 关闭混合。 */
	public var shadowCascadeBlend(get, set):Float;
	private var __shadowCascadeBlend:Float = 0.15;
	private function get_shadowCascadeBlend():Float { return __shadowCascadeBlend; }
	private function set_shadowCascadeBlend(value:Float):Float {
		var changed = !hasShadowOverride("shadowCascadeBlend") || __shadowCascadeBlend != value;
		__shadowCascadeBlend = value; __shadowOverrides.set("shadowCascadeBlend", true);
		if (changed) invalidate();
		return value;
	}

	/** 距离末端的淡出比例，范围 0～0.5，默认 0.1；0 关闭距离淡出。 */
	public var shadowFadeRatio(get, set):Float;
	private var __shadowFadeRatio:Float = 0.1;
	private function get_shadowFadeRatio():Float { return __shadowFadeRatio; }
	private function set_shadowFadeRatio(value:Float):Float {
		var changed = !hasShadowOverride("shadowFadeRatio") || __shadowFadeRatio != value;
		__shadowFadeRatio = value; __shadowOverrides.set("shadowFadeRatio", true);
		if (changed) invalidate();
		return value;
	}

	/** 几何法线偏移，以每级阴影纹素的世界尺寸为单位，默认 0.5。 */
	public var shadowNormalBias(get, set):Float;
	private var __shadowNormalBias:Float = 0.5;
	private function get_shadowNormalBias():Float { return __shadowNormalBias; }
	private function set_shadowNormalBias(value:Float):Float {
		var changed = !hasShadowOverride("shadowNormalBias") || __shadowNormalBias != value;
		__shadowNormalBias = value; __shadowOverrides.set("shadowNormalBias", true);
		if (changed) invalidate();
		return value;
	}

	/** 可选世界空间范围；为空时覆盖相机附近区域，避免远处物体持续降低阴影精度。 */
	public var shadowBounds:Bounds3D;

	/** 显式过滤模式；未覆盖时按质量档位选择，读取请求默认值 PCF4。 */
	public var shadowFilter(get, set):ShadowFilter3D;
	private var __shadowFilter:ShadowFilter3D = ShadowFilter3D.PCF4;
	private function get_shadowFilter():ShadowFilter3D { return __shadowFilter; }
	private function set_shadowFilter(value:ShadowFilter3D):ShadowFilter3D {
		var changed = !hasShadowOverride("shadowFilter") || __shadowFilter != value;
		__shadowFilter = value; __shadowOverrides.set("shadowFilter", true);
		if (changed) invalidate();
		return value;
	}

	/** 显式 PCF9 半径，范围 0～1.5 阴影纹素；0 硬采样。自动档用 1.25，请求默认值 1.5。 */
	public var shadowFilterRadius(get, set):Float;
	private var __shadowFilterRadius:Float = 1.5;
	private function get_shadowFilterRadius():Float { return __shadowFilterRadius; }
	private function set_shadowFilterRadius(value:Float):Float {
		var changed = !hasShadowOverride("shadowFilterRadius") || __shadowFilterRadius != value;
		__shadowFilterRadius = value; __shadowOverrides.set("shadowFilterRadius", true);
		if (changed) invalidate();
		return value;
	}

	/** 默认自动检测投影内容变化；关闭后调用 requestShadowUpdate 更新。 */
	public var shadowAutoUpdate:Bool = true;

	/** 手动更新请求版本，供后端检测；请求同时使场景失效。 */
	public var shadowUpdateVersion(default, null):Int = 0;

	/** 首次启用及目标重建始终生成阴影；其余手动更新通过此方法请求。 */
	public function requestShadowUpdate():Void {
		shadowUpdateVersion++;
		invalidate();
	}

	/** 创建方向光节点；加入场景后通过 addLight 注册，或赋给 Scene3D.light。 */
	public function new(color:Int = 0xffffff, intensity:Float = 1) {
		super(color, intensity);
	}

	/** 同时用于参数校验和静态场景失效检测，不读取 GPU 状态。 */
	override public function settingsKey():String {
		var base = super.settingsKey();
		if (shadowQuality != ShadowQuality3D.LEGACY && shadowQuality != ShadowQuality3D.PERFORMANCE
			&& shadowQuality != ShadowQuality3D.BALANCED && shadowQuality != ShadowQuality3D.HIGH)
			throw "阴影质量档位无效";
		var overrides = [for (name in __shadowOverrides.keys()) name]; overrides.sort(Reflect.compare);
		for (value in [intensity, shadowBias, shadowSlopeBias, shadowPadding, shadowNormalBias])
			if (!Math3D.finite(value) || value < 0)
				throw "方向光强度或阴影参数无效";
		if (shadowMapSize < 16 || shadowMapSize > 8192 || (shadowMapSize & (shadowMapSize - 1)) != 0)
			throw "阴影尺寸必须是 16～8192 的二次幂";
		if (!Math3D.finite(shadowDistance) || shadowDistance < 0) throw "阴影覆盖距离必须为非负有限值";
		if (shadowCascadeCount != 1 && shadowCascadeCount != 2) throw "阴影级联数量必须为 1 或 2";
		if (!Math3D.finite(shadowFadeRatio) || shadowFadeRatio < 0 || shadowFadeRatio > 0.5) throw "阴影淡出比例必须为 0～0.5";
		if (shadowCascadeSplit != null && (!Math3D.finite(shadowCascadeSplit) || shadowCascadeSplit <= 0 || shadowCascadeSplit >= 1))
			throw "近级联深度占比必须大于 0 且小于 1";
		if (!Math3D.finite(shadowCascadeBlend) || shadowCascadeBlend < 0 || shadowCascadeBlend > 0.5)
			throw "级联混合比例必须为 0～0.5";
		if (!Math3D.finite(shadowFilterRadius) || shadowFilterRadius < 0 || shadowFilterRadius > 1.5)
			throw "PCF9 过滤半径必须为 0～1.5 个阴影纹素";
		if (shadowBounds != null) {
			if (shadowBounds.isEmpty())
				throw "阴影范围不能为空";
			for (value in [
				shadowBounds.min.x,
				shadowBounds.min.y,
				shadowBounds.min.z,
				shadowBounds.max.x,
				shadowBounds.max.y,
				shadowBounds.max.z
			])
				if (!Math3D.finite(value))
					throw "阴影范围必须是有限值";
		}
		if (shadowFilter != ShadowFilter3D.HARD && shadowFilter != ShadowFilter3D.PCF4 && shadowFilter != ShadowFilter3D.PCF9)
			throw "阴影过滤模式无效";
		var d = getWorldDirection();
		var values:Array<Dynamic> = [
			color,
			intensity,
			isWorldVisible(),
			d.x,
			d.y,
			d.z,
			shadowEnabled,
			shadowQuality,
			overrides.join(","),
			shadowFilter,
			shadowAutoUpdate,
			shadowUpdateVersion,
			shadowMapSize,
			shadowBias,
			shadowSlopeBias,
			shadowPadding,
			shadowDistance,
			shadowCascadeCount,
			shadowCascadeSplit,
			shadowCascadeBlend,
			shadowFilterRadius,
			shadowFadeRatio,
			shadowNormalBias,
			shadowBounds == null ? "自动" : [
				shadowBounds.min.x,
				shadowBounds.min.y,
				shadowBounds.min.z,
				shadowBounds.max.x,
				shadowBounds.max.y,
				shadowBounds.max.z
			].join(",")
		];
		return base + ":" + values.join(":");
	}
}
