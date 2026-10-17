package hx.light;

import hx.display3d.Node3D;
import hx.geom.Vector3D;
import hx.geom.Bounds3D;
import hx.render3d.Math3D;

/** 方向表示光传播方向；加入 Scene3D.root 后可作为该场景的单方向光。 */
class DirectionalLight3D extends Node3D {
	/** 方向光 RGB 颜色，默认白色。 */
	public var color:Int = 0xffffff;

	/** 非负有限光照强度，默认 1。 */
	public var intensity:Float = 1;

	/** 是否请求阴影，默认关闭，实际支持结果见场景统计。 */
	public var shadowEnabled:Bool = false;

	/** 阴影贴图边长，默认 1024，允许 16 至 8192 的二次幂。 */
	public var shadowMapSize:Int = 1024;

	/** 阴影深度常量偏移，默认 0.001，必须非负有限。 */
	public var shadowBias:Float = 0.001;

	/** 随表面倾角增加的深度偏移，默认 0.002，必须非负有限。 */
	public var shadowSlopeBias:Float = 0.002;

	/** 自动阴影范围的非负留边比例，默认 0.1。 */
	public var shadowPadding:Float = 0.1;

	/** 可选世界空间范围；为空时自动适配投射物与接收深度。 */
	public var shadowBounds:Bounds3D;

	/** 默认硬阴影；可切换为四次比较的 PCF4。 */
	public var shadowFilter:ShadowFilter3D = ShadowFilter3D.HARD;

	/** 默认自动检测投影内容变化；关闭后调用 requestShadowUpdate 更新。 */
	public var shadowAutoUpdate:Bool = true;

	/** 手动更新请求版本，供后端检测；请求同时使场景失效。 */
	public var shadowUpdateVersion(default, null):Int = 0;

	/** 首次启用及目标重建始终生成阴影；其余手动更新通过此方法请求。 */
	public function requestShadowUpdate():Void {
		shadowUpdateVersion++;
		invalidate();
	}

	private var __direction:Vector3D = new Vector3D(-1, -2, -1);

	/** 局部光传播方向；设置时复制并归一化，读取返回副本。 */
	public var direction(get, set):Vector3D;

	private function get_direction():Vector3D {
		return __direction.clone();
	}

	private function set_direction(value:Vector3D):Vector3D {
		if (value == null || !Math3D.finite(value.x) || !Math3D.finite(value.y) || !Math3D.finite(value.z))
			throw "方向光方向无效";
		var copy = value.clone();
		if (copy.normalize() < 1e-10)
			throw "方向光方向不能为零";
		__direction = copy;
		invalidate();
		return value;
	}

	/** 创建方向光节点；使用前加入场景并赋给 Scene3D.light。 */
	public function new(color:Int = 0xffffff, intensity:Float = 1) {
		super();
		this.color = color;
		this.intensity = intensity;
	}

	/** 返回应用节点世界变换后归一化的光传播方向。 */
	public function getWorldDirection():Vector3D {
		var m = getWorldMatrix().rawData, d = __direction;
		var result = new Vector3D(m[0] * d.x + m[4] * d.y + m[8] * d.z, m[1] * d.x + m[5] * d.y + m[9] * d.z, m[2] * d.x + m[6] * d.y + m[10] * d.z);
		if (result.normalize() < 1e-10)
			throw "方向光变换使方向退化";
		return result;
	}

	/** 同时用于参数校验和静态场景失效检测，不读取 GPU 状态。 */
	public function settingsKey():String {
		for (value in [intensity, shadowBias, shadowSlopeBias, shadowPadding])
			if (!Math3D.finite(value) || value < 0)
				throw "方向光强度或阴影参数无效";
		if (shadowMapSize < 16 || shadowMapSize > 8192 || (shadowMapSize & (shadowMapSize - 1)) != 0)
			throw "阴影尺寸必须是 16～8192 的二次幂";
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
			shadowBounds == null ? "自动" : [
				shadowBounds.min.x,
				shadowBounds.min.y,
				shadowBounds.min.z,
				shadowBounds.max.x,
				shadowBounds.max.y,
				shadowBounds.max.z
			].join(",")
		];
		return values.join(":");
	}
}
