package hx.light;

import hx.render3d.Math3D;

/** 在点光距离衰减上叠加平滑聚光锥；方向使用继承的局部 direction。 */
class SpotLight3D extends PointLight3D {
	/** 内锥半角，单位为度；内锥以内不衰减，必须小于外锥半角。 */
	public var innerAngle:Float = 18;
	/** 外锥半角，单位为度，必须小于 90。 */
	public var outerAngle:Float = 30;

	public function new(color:Int = 0xffffff, intensity:Float = 1, range:Float = 10) {
		super(color, intensity, range);
	}

	override public function settingsKey():String {
		if (!Math3D.finite(innerAngle) || !Math3D.finite(outerAngle)
			|| innerAngle < 0 || innerAngle >= outerAngle || outerAngle >= 90)
			throw "聚光半角必须满足 0 ≤ 内锥 < 外锥 < 90 度";
		return super.settingsKey() + ":" + innerAngle + ":" + outerAngle;
	}
}
