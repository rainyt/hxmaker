package hx.particle;

class FourAttribute implements Attribute {
	public var x:Attribute = new OneAttribute(1);

	public var y:Attribute = new OneAttribute(1);

	public var z:Attribute = new OneAttribute(1);

	public var w:Attribute = new OneAttribute(1);

	public function new(x:Dynamic = null, y:Dynamic = null, z:Dynamic = null, w:Dynamic = null) {
		if (x != null)
			this.x = toAttribute(x);
		if (y != null)
			this.y = toAttribute(y);
		if (w != null)
			this.w = toAttribute(w);
		if (z != null)
			this.z = toAttribute(z);
	}

	private function toAttribute(value:Dynamic):Attribute {
		if (Std.isOfType(value, Attribute))
			return value;
		return new OneAttribute(value);
	}

	public function setColor(r:Float, g:Float, b:Float, a:Float):Void {
		this.x = new OneAttribute(r);
		this.y = new OneAttribute(g);
		this.z = new OneAttribute(b);
		this.w = new OneAttribute(a);
	}

	public function copy():FourAttribute {
		return new FourAttribute(x.copy(), y.copy(), z.copy(), w.copy());
	}

	public var type(get, never):String;

	private function get_type():String {
		return "four";
	}

	public function getValue():Float {
		return x.getValue() + y.getValue() + z.getValue() + w.getValue();
	}
}
