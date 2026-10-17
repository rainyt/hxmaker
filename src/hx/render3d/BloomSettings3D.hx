package hx.render3d;

/** 基于普通颜色目标的泛光设置，默认关闭；不要求浮点纹理或 HDR。 */
class BloomSettings3D {
	public var enabled:Bool = false;
	/** 显示空间 RGB 最大分量的提取阈值，范围零至一。 */
	public var threshold:Float = 0.65;
	public var intensity:Float = 0.8;
	/** 模糊偏移倍率，以降采样目标像素为单位。 */
	public var radius:Float = 2;
	public var renderScale:Float = 0.5;

	public function new() {}

	public function settingsKey():String {
		for (value in [threshold, intensity, radius, renderScale])
			if (!Math3D.finite(value)) throw "泛光参数必须有限";
		if (threshold < 0 || threshold > 1 || intensity < 0 || intensity > 8 || radius < 0 || radius > 16
			|| renderScale < 0.125 || renderScale > 1) throw "泛光参数范围无效";
		return [enabled ? 1. : 0., threshold, intensity, radius, renderScale].join(":");
	}
}
