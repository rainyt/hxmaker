package hx.particle;

class TweenAttribute {
	/**
	 * 总权重值
	 */
	public var allWeigth:Float;

	public var attributes:Array<WeightTweenAttribute> = [];

	public function new() {}

	/**
	 * 更新权重值
	 * @return Float
	 */
	public function updateWeight():Float {
		allWeigth = 0;
		for (index => value in attributes) {
			allWeigth += value.weight;
		}
		var nowWeight:Float = 0;
		for (index => value in attributes) {
			nowWeight += value.weight;
			value.aliveTimeScale = nowWeight / allWeigth;
		}
		return allWeigth;
	}
}
