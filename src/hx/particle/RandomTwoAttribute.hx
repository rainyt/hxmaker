package hx.particle;

/**
 * 两个数值之间的随时值
 */
class RandomTwoAttribute implements Attribute {
	public static function create(startRandom:Float, endRandom:Float):Attribute {
		return new RandomTwoAttribute(startRandom, endRandom);
	}

	public var startRandom:Float;

	public var endRandom:Float;

	public function new(startRandom:Float, endRandom:Float) {
		this.startRandom = startRandom;
		this.endRandom = endRandom;
	}

	public function get_type():String {
		return "random2";
	}

	public var type(get, never):String;

	public function getValue():Float {
		return startRandom + Math.random() * (endRandom - startRandom);
	}

	public function copy():Attribute {
		return new RandomTwoAttribute(startRandom, endRandom);
	}
}
