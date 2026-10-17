package hx.effect3d;

import hx.render3d.Math3D;

/** 拖尾与刀光共用的寿命、采样容量、宽度及颜色配置。 */
class TrailSettings3D {
	public var lifetime:Float = 0.45;
	public var maxSections:Int = 128;

	/** 新截面两端的最大移动距离小于此值时不采样，单位为世界单位。 */
	public var minDistance:Float = 0.015;

	/** Trail3D 的世界宽度；Ribbon3D 的双端截面宽度倍率。 */
	public var width:Float = 1;

	public var widthOverLife:FloatCurve3D = new FloatCurve3D([0., 1.], [1., 0.]);
	public var alpha:FloatCurve3D = new FloatCurve3D([0., 1.], [1., 0.]);
	public var red:FloatCurve3D = FloatCurve3D.constant(1);
	public var green:FloatCurve3D = FloatCurve3D.constant(1);
	public var blue:FloatCurve3D = FloatCurve3D.constant(1);

	/** 零将整条轨迹映射到零至一；正数按世界距离重复，需配合重复采样材质。 */
	public var textureRepeatLength:Float = 0;

	/** 单次位移超过此距离时断开轨迹；零不限制，避免瞬移形成长条。 */
	public var breakDistance:Float = 3;

	public function new() {}

	public function validate():Void {
		for (v in [lifetime, minDistance, width, textureRepeatLength, breakDistance])
			if (!Math3D.finite(v))
				throw "拖尾参数必须有限";
		if (lifetime <= 0 || minDistance < 0 || width < 0 || textureRepeatLength < 0 || breakDistance < 0 || maxSections < 2 || maxSections > 32767
			|| widthOverLife == null || alpha == null || red == null || green == null || blue == null)
			throw "拖尾参数范围无效，截面容量必须介于二至 32767";
	}
}
