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
	 * 扩展
	 */
	public function expand(x:Float, y:Float, width:Float, height:Float):Void {
		if (this.width == 0 && this.height == 0) {
			this.x = x;
			this.y = y;
			this.width = width;
			this.height = height;
			return;
		}
		var cacheRight = right;
		var cacheBottom = bottom;

		if (this.x > x) {
			this.x = x;
			this.width = cacheRight - x;
		}
		if (this.y > y) {
			this.y = y;
			this.height = cacheBottom - y;
		}
		if (cacheRight < x + width)
			this.width = x + width - this.x;
		if (cacheBottom < y + height)
			this.height = y + height - this.y;
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

	/**
		The _x_ coordinate of the top-left corner of the rectangle. Changing
		the `left` property of a Rectangle object has no effect on the `y` and
		`height` properties. However it does affect the `width` property,
		whereas changing the `x` value does _not_ affect the `width` property.

		The value of the `left` property is equal to the value of the `x`
		property.

		![A rectangle image showing location and measurement properties.](/images/rectangle.jpg)
	**/
	public var left(get, set):Float;

	/**
		The sum of the `x` and `width` properties.

		![A rectangle image showing location and measurement properties.](/images/rectangle.jpg)
	**/
	public var right(get, set):Float;

	/**
		The _y_ coordinate of the top-left corner of the rectangle. Changing
		the `top` property of a Rectangle object has no effect on the `x` and
		`width` properties. However it does affect the `height` property,
		whereas changing the `y` value does _not_ affect the `height`
		property.
		The value of the `top` property is equal to the value of the `y`
		property.

		![A rectangle image showing location and measurement properties.](/images/rectangle.jpg)
	**/
	public var top(get, set):Float;

	/**
		The sum of the `y` and `height` properties.

		![A rectangle image showing location and measurement properties.](/images/rectangle.jpg)
	**/
	public var bottom(get, set):Float;

	// Getters & Setters
	@:noCompletion private function get_bottom():Float {
		return y + height;
	}

	@:noCompletion private function set_bottom(b:Float):Float {
		height = b - y;
		return b;
	}

	@:noCompletion private function get_left():Float {
		return x;
	}

	@:noCompletion private function set_left(l:Float):Float {
		width -= l - x;
		x = l;
		return l;
	}

	@:noCompletion private function get_right():Float {
		return x + width;
	}

	@:noCompletion private function set_right(r:Float):Float {
		width = r - x;
		return r;
	}

	@:noCompletion private function get_top():Float {
		return y;
	}

	@:noCompletion private function set_top(t:Float):Float {
		height -= t - y;
		y = t;
		return t;
	}

	public function toString():String {
		return "[" + x + "," + y + "," + width + "," + height + "]";
	}

	public function clone():Rectangle {
		return new Rectangle(x, y, width, height);
	}

	/**
	 * 设置CSS样式
	 * @param css 
	 * @param width 
	 * @param height 
	 */
	public function css(css:String, width:Float, height:Float):Void {
		var arr:Array<String> = css.split(" ");
		this.x = Std.parseFloat(arr[3]);
		this.y = Std.parseFloat(arr[0]);
		this.width = width - Std.parseFloat(arr[1]) - Std.parseFloat(arr[3]);
		this.height = height - Std.parseFloat(arr[0]) - Std.parseFloat(arr[2]);
	}
}
