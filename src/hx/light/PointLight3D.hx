package hx.light;

import hx.render3d.Math3D;

/** 有限范围点光；强度乘以 (1-distance/range)²，超出范围不贡献光照。 */
class PointLight3D extends Light3D {
	/** 世界空间照明半径，必须为正有限值；节点缩放不改变半径。 */
	public var range:Float = 10;

	public function new(color:Int = 0xffffff, intensity:Float = 1, range:Float = 10) {
		super(color, intensity);
		this.range = range;
	}

	override public function settingsKey():String {
		if (!Math3D.finite(range) || range <= 0) throw "点光范围必须为正有限值";
		return super.settingsKey() + ":" + range;
	}
}
