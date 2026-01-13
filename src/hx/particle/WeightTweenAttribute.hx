package hx.particle;

import hx.particle.OneTweenAttribute.OneTweenChildAttribute;
import hx.particle.FourTweenAttribute.FourTweenChildAttribute;

class WeightTweenAttribute {
	public var weight:Float;

	/**
	 * 生命周期比例
	 */
	public var aliveTimeScale:Float;

	public function new(weight:Float) {
		this.weight = weight;
	}

	public function asFourAttribute():FourTweenChildAttribute {
		return cast this;
	}

	public function asOneAttribute():OneTweenChildAttribute {
		return cast this;
	}
}
