package hx.particle;

class FourTweenAttribute extends TweenAttribute {
	public function pushAttribute(weight:Float, attribute:FourAttribute) {
		this.attributes.push(new FourTweenChildAttribute(weight, attribute));
	}
}

class FourTweenChildAttribute extends WeightTweenAttribute {
	public var attribute:FourAttribute;

	public function new(weight:Float, attribute:FourAttribute) {
		super(weight);
		this.attribute = attribute;
	}
}
