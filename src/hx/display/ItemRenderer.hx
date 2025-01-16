package hx.display;

class ItemRenderer extends Box implements IDataProider<Dynamic> implements ISelectProider {
	private var __value:Dynamic;

	public var data(get, set):Dynamic;

	private function set_data(value:Dynamic):Dynamic {
		this.__value = value;
		this.setData(value);
		return value;
	}

	private function get_data():Dynamic {
		return __value;
	}

	public function setData(value:Dynamic):Void {}

	public var selected(get, set):Bool;

	private var __selected:Bool = false;

	function set_selected(value:Bool):Bool {
		__selected = value;
		setSelected(value);
		return value;
	}

	function get_selected():Bool {
		return __selected;
	}

	public function setSelected(selected:Bool):Void {}
}
