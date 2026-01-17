package hx.particle;

class TweenAttribute {
	/**
	 * 开始值
	 */
	public var start:Attribute;

	/**
	 * 结束值
	 */
	public var end:Attribute;

	/**
	 * 开始值过渡偏移
	 */
	public var startOffset:Float = 0;

	/**
	 * 结束值过渡偏移
	 */
	public var endOffset:Float = 1;

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

	public function update(aliveTime:Float, groupStart:Attribute, groupEnd:Attribute) {
		if (attributes.length > 0) {
			for (index => value in attributes) {
				if (value.aliveTimeScale >= aliveTime) {
					if (index == 0) {
						this.startOffset = 0;
						this.endOffset = value.asFourAttribute().aliveTimeScale;
						this.start = groupStart;
						this.end = value.asFourAttribute().attribute;
						return;
					} else {
						this.startOffset = attributes[index - 1].asFourAttribute().aliveTimeScale;
						this.endOffset = value.asFourAttribute().aliveTimeScale;
						this.start = attributes[index - 1].asFourAttribute().attribute;
						this.end = value.asFourAttribute().attribute;
						return;
					}
				}
			}
			var value = attributes[0];
			this.startOffset = 0;
			this.endOffset = value.asFourAttribute().aliveTimeScale;
			this.start = groupStart;
			this.end = value.asFourAttribute().attribute;
		} else {
			this.startOffset = 0;
			this.endOffset = 1;
			this.start = groupStart;
			this.end = groupEnd;
		}
	}

	/**
	 * 清空
	 */
	public function clear():Void {
		this.attributes = [];
	}
}
