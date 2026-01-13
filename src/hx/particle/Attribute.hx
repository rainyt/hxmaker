package hx.particle;


interface Attribute {
	public var type(get, never):String;

	public function getValue():Float;

	public function copy():Attribute;
}
