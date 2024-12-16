package hx.gemo;

/**
 * 矩形
 */
class Rectangle {
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;

	public function new(x:Float, y:Float, width:Float, height:Float) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	public function setTo(x:Float, y:Float, width:Float, height:Float):Void {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	@:noCompletion private function __transform(rect:Rectangle, m:Matrix):Void {
		var tx0 = m.a * x + m.c * y;
		var tx1 = tx0;
		var ty0 = m.b * x + m.d * y;
		var ty1 = ty0;

		var tx = m.a * (x + width) + m.c * y;
		var ty = m.b * (x + width) + m.d * y;

		if (tx < tx0)
			tx0 = tx;
		if (ty < ty0)
			ty0 = ty;
		if (tx > tx1)
			tx1 = tx;
		if (ty > ty1)
			ty1 = ty;

		tx = m.a * (x + width) + m.c * (y + height);
		ty = m.b * (x + width) + m.d * (y + height);

		if (tx < tx0)
			tx0 = tx;
		if (ty < ty0)
			ty0 = ty;
		if (tx > tx1)
			tx1 = tx;
		if (ty > ty1)
			ty1 = ty;

		tx = m.a * x + m.c * (y + height);
		ty = m.b * x + m.d * (y + height);

		if (tx < tx0)
			tx0 = tx;
		if (ty < ty0)
			ty0 = ty;
		if (tx > tx1)
			tx1 = tx;
		if (ty > ty1)
			ty1 = ty;

		rect.setTo(tx0 + m.tx, ty0 + m.ty, tx1 - tx0, ty1 - ty0);
	}
}
