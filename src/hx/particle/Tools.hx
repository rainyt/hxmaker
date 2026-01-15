package hx.particle;

import hx.particle.data.*;

class Tools {
	public static function asOneAttribute(value:Attribute):OneAttribute {
		return cast value;
	}

	public static function asRandomTwoAttribute(value:Attribute):RandomTwoAttribute {
		return cast value;
	}

	public static function asTwoAttribute(value:Attribute):TwoAttribute {
		return cast value;
	}

	public static function asFourAttribute(value:Attribute):FourAttribute {
		return cast value;
	}
}
