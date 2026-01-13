package hx.particle;

/**
 * 单个数值
 */
class OneAttribute implements Attribute {
	public static function create(value:Float):Attribute {
		return new OneAttribute(value);
	}

	public var value:Float;

	public function new(value:Float) {
		this.value = value;
	}

	public var type(get, never):String;

	function get_type():String {
		return "one";
	}

	public function getValue():Float {
		return value;
	}

	public function copy():Attribute {
		return new OneAttribute(value);
	}
}
