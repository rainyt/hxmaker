package hx.particle;

class FourTweenAttribute extends TweenAttribute {
	/**
	 * 开始值
	 */
	public var start:FourAttribute;

	/**
	 * 结束值
	 */
	public var end:FourAttribute;

	/**
	 * 开始值过渡偏移
	 */
	public var startOffset:Float = 0;

	/**
	 * 结束值过渡偏移
	 */
	public var endOffset:Float = 1;

	public function pushAttribute(weight:Float, attribute:FourAttribute) {
		this.attributes.push(new FourTweenChildAttribute(weight, attribute));
	}

	public function update(aliveTime:Float, groupStart:FourAttribute, groupEnd:FourAttribute) {
		if (attributes.length > 0) {
			for (index => value in attributes) {
				if (value.aliveTimeScale >= aliveTime) {
					if (index == 0) {
						this.startOffset = 0;
						this.endOffset = value.asFourAttribute().aliveTimeScale;
						this.start = groupStart;
						this.end = value.asFourAttribute().attribute;
						break;
					} else {
						this.startOffset = attributes[index - 1].asFourAttribute().aliveTimeScale;
						this.endOffset = value.asFourAttribute().aliveTimeScale;
						this.start = attributes[index - 1].asFourAttribute().attribute;
						this.end = value.asFourAttribute().attribute;
						break;
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
}

class FourTweenChildAttribute extends WeightTweenAttribute {
	public var attribute:FourAttribute;

	public function new(weight:Float, attribute:FourAttribute) {
		super(weight);
		this.attribute = attribute;
	}
}
