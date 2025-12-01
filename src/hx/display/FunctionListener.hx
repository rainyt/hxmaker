package hx.display;

class FunctionListener {
	/**
	 * 是否只调用一次
	 */
	public var onely:Bool = false;

	private var __callbacks:Array<Void->Void> = [];

	private var __called:Bool = false;

	public function new(onely:Bool = false) {
		this.onely = onely;
	}

	public function add(cb:Void->Void):Void {
		__callbacks.push(cb);
		if (onely && __called) {
			cb();
		}
	}

	public function call():Void {
		for (cb in __callbacks) {
			cb();
		}
		__called = true;
	}
}
