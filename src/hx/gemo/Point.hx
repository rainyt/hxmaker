package hx.gemo;

class Point {
	public var x:Float = 0;

	public var y:Float = 0;

	public function new(x:Float = 0, y:Float = 0) {
		this.x = x;
		this.y = y;
	}

	public function clone():Point {
		return new Point(x, y);
	}

	public function set(x:Float, y:Float):Void {
		this.x = x;
		this.y = y;
	}
}
