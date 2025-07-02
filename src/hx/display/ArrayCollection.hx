package hx.display;

import hx.events.Event;

/**
 * 数组
 */
class ArrayCollection extends EventDispatcher {
	public var source:Array<Dynamic>;

	public function new(array:Array<Dynamic>) {
		this.source = array;
	}

	public function remove(item:Dynamic):Bool {
		var index = source.indexOf(item);
		if (index < 0)
			return false;
		source.splice(index, 1);
		this.dispatchEvent(new Event(Event.REMOVED, item));
		return true;
	}

	public function add(item:Dynamic):Bool {
		if (source.indexOf(item) >= 0)
			return false;
		source.push(item);
		this.dispatchEvent(new Event(Event.ADDED, item));
		return true;
	}

	public var length(get, null):Int;

	private function get_length():Int {
		return source.length;
	}
}
