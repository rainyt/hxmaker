package hx.particle;

class FourTweenAttribute extends TweenAttribute {
	public function pushAttribute(weight:Float, attribute:FourAttribute) {
		this.attributes.push(new FourTweenChildAttribute(weight, attribute));
	}
}

class FourTweenChildAttribute extends WeightTweenAttribute {
	public var fourAttribute(get, never):FourAttribute;

	private function get_fourAttribute():FourAttribute {
		return cast attribute;
	}

	public function new(weight:Float, attribute:FourAttribute) {
		super(weight);
		this.attribute = attribute;
	}
}
