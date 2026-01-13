package hx.particle;

class OneTweenAttribute extends TweenAttribute {
	public function pushAttribute(weight:Float, attribute:Attribute) {
		this.attributes.push(new OneTweenChildAttribute(weight, attribute));
	}
}

class OneTweenChildAttribute extends WeightTweenAttribute {
	public var attribute:Attribute;

	public function new(weight:Float, attribute:Attribute) {
		super(weight);
		this.attribute = attribute;
	}
}
