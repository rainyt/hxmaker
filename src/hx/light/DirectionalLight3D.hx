package hx.light;

import hx.geom.Bounds3D;
import hx.render3d.Math3D;

/** 方向表示光传播方向；可注册为普通方向光，或通过 Scene3D.light 指定为带阴影的主光。 */
class DirectionalLight3D extends Light3D {
	/** 是否请求阴影，默认关闭，实际支持结果见场景统计。 */
	public var shadowEnabled:Bool = false;

	/** 阴影贴图边长，默认 1024，允许 16 至 8192 的二次幂。 */
	public var shadowMapSize:Int = 1024;

	/** 阴影深度常量偏移，默认 0.0001，必须非负有限。 */
	public var shadowBias:Float = 0.0001;

	/** 随表面倾角增加的深度偏移，默认 0.0005，必须非负有限。 */
	public var shadowSlopeBias:Float = 0.0005;

	/** 自动阴影范围的非负留边比例，默认 0.1。 */
	public var shadowPadding:Float = 0.1;

	/** 自动阴影覆盖的相机前向距离，默认 100；0 表示沿用 camera.far，手动范围优先。 */
	public var shadowDistance:Float = 100;

	/** 自动取景级联数量，允许 1 或 2，默认 2；手动世界范围固定使用单级。 */
	public var shadowCascadeCount:Int = 2;

	/** 距离末端的淡出比例，范围 0～0.5，默认 0.1；0 关闭距离淡出。 */
	public var shadowFadeRatio:Float = 0.1;

	/** 几何法线偏移，以每级阴影纹素的世界尺寸为单位，默认 0.5。 */
	public var shadowNormalBias:Float = 0.5;

	/** 可选世界空间范围；为空时覆盖相机附近区域，避免远处物体持续降低阴影精度。 */
	public var shadowBounds:Bounds3D;

	/** 默认按亚纹素位置加权的 PCF4；低成本模式可切换 HARD。 */
	public var shadowFilter:ShadowFilter3D = ShadowFilter3D.PCF4;

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
		for (value in [intensity, shadowBias, shadowSlopeBias, shadowPadding, shadowNormalBias])
			if (!Math3D.finite(value) || value < 0)
				throw "方向光强度或阴影参数无效";
		if (shadowMapSize < 16 || shadowMapSize > 8192 || (shadowMapSize & (shadowMapSize - 1)) != 0)
			throw "阴影尺寸必须是 16～8192 的二次幂";
		if (!Math3D.finite(shadowDistance) || shadowDistance < 0) throw "阴影覆盖距离必须为非负有限值";
		if (shadowCascadeCount != 1 && shadowCascadeCount != 2) throw "阴影级联数量必须为 1 或 2";
		if (!Math3D.finite(shadowFadeRatio) || shadowFadeRatio < 0 || shadowFadeRatio > 0.5) throw "阴影淡出比例必须为 0～0.5";
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
		if (shadowFilter != ShadowFilter3D.HARD && shadowFilter != ShadowFilter3D.PCF4)
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
			shadowFilter,
			shadowAutoUpdate,
			shadowUpdateVersion,
			shadowMapSize,
			shadowBias,
			shadowSlopeBias,
			shadowPadding,
			shadowDistance,
			shadowCascadeCount,
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
