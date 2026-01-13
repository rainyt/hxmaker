package hx.particle;

class ArrayAttribute implements Attribute {
	private var _array:Array<Float>;

	private var _arrayIndex:Int = 0;

	public function new(array:Array<Float>) {
		_array = array;
	}

	public function get_type():String {
		return "array-value";
	}

	public var type(get, never):String;

	public function getValue():Float {
		var value = _array[_arrayIndex];
		_arrayIndex++;
		if (_arrayIndex > _array.length)
			_arrayIndex = 0;
		return _array[_arrayIndex];
	}

	public function copy():Attribute {
		return new ArrayAttribute(_array);
	}
}
