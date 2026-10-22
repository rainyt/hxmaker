package hx.effect3d;

import hx.render3d.Math3D;

/** 不可变分段线性曲线，时间为归一化寿命；区间外取端点值。 */
class FloatCurve3D {
	private var times:Array<Float>;
	private var values:Array<Float>;

	public function new(times:Array<Float>, values:Array<Float>) {
		if (times == null || values == null || times.length == 0 || times.length != values.length)
			throw "曲线时间和值数量必须一致且非空";
		for (i in 0...times.length)
			if (!Math3D.finite(times[i]) || times[i] < 0 || times[i] > 1 || !Math3D.finite(values[i]) || (i > 0 && times[i] <= times[i - 1]))
				throw "曲线时间必须在零至一之间严格递增，值必须有限";
		this.times = times.copy();
		this.values = values.copy();
	}

	public static function constant(value:Float):FloatCurve3D {
		return new FloatCurve3D([0.], [value]);
	}

	public function evaluate(t:Float):Float {
		if (!Math3D.finite(t))
			throw "曲线时间必须有限";
		if (t <= times[0])
			return values[0];
		for (i in 1...times.length)
			if (t < times[i]) {
				var weight = (t - times[i - 1]) / (times[i] - times[i - 1]);
				return values[i - 1] + (values[i] - values[i - 1]) * weight;
			}
		return values[values.length - 1];
	}
}
