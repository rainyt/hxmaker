package hx.gemo;

/**
 * 矩形
 */
class Rectangle {
	/**
	 * 坐标X
	 */
	public var x:Float;

	/**
	 * 坐标Y
	 */
	public var y:Float;

	/**
	 * 宽度
	 */
	public var width:Float;

	/**
	 * 高度
	 */
	public var height:Float;

	public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	/**
	 * 设置矩形
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 */
	public function setTo(x:Float, y:Float, width:Float, height:Float):Void {
		this.x = x;
		this.y = y;
		this.width = width;
		this.height = height;
	}

	/**
	 * 将矩形坐标变换到目标矩形
	 * @param rect 
	 * @param m 
	 */
	public function transform(rect:Rectangle, m:Matrix):Void {
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

	/**
	 * 当前矩阵是否包含点
	 * @param x 
	 * @param y 
	 * @return Bool
	 */
	public function containsPoint(x:Float, y:Float):Bool {
		return (x >= this.x && x <= this.x + this.width && y >= this.y && y <= this.y + this.height);
	}
}
