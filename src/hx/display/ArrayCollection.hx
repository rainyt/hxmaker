package hx.display;

class ArrayCollection extends EventDispatcher {
	public var source:Array<Dynamic>;

	public function new(array:Array<Dynamic>) {
		this.source = array;
	}
}
