package hx.display;

class FunctionListener {
	private var __callbacks:Array<Void->Void> = [];

	public function new() {}

	public function add(cb:Void->Void):Void {
		__callbacks.push(cb);
	}

	public function call():Void {
		for (cb in __callbacks) {
			cb();
		}
	}
}
