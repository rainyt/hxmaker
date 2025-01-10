package hx.gemo;

class Point {
	/**
	 * 计算两个坐标的距离
	 * @param p1 
	 * @param p2 
	 * @return Float
	 */
	public static function distance(p1:Point, p2:Point):Float {
		return distanceByFloat(p1.x, p1.y, p2.x, p2.y);
	}

	/**
	 * 通过坐标计算距离
	 * @param x1 
	 * @param y1 
	 * @param x2 
	 * @param y2 
	 * @return Float
	 */
	public static function distanceByFloat(x1:Float, y1:Float, x2:Float, y2:Float):Float {
		var dx = x1 - x2;
		var dy = y1 - y2;
		return Math.sqrt(dx * dx + dy * dy);
	}

	/**
	 * 通过两个坐标计算弧度
	 * @param p1 
	 * @param p2 
	 * @return Float
	 */
	public static function radian(p1:Point, p2:Point):Float {
		return radianByFloat(p1.x, p1.y, p2.x, p2.y);
	}

	/**
	 * 通过浮点数计算弧度
	 * @param x1 
	 * @param y1 
	 * @param x2 
	 * @param y2 
	 * @return Float
	 */
	public static function radianByFloat(x1:Float, y1:Float, x2:Float, y2:Float):Float {
		var dx = x1 - x2;
		var dy = y1 - y2;
		return Math.atan2(dy, dx);
	}

	public static function rotation(p1:Point, p2:Point):Float {
		return rotationByFloat(p1.x, p1.y, p2.x, p2.y);
	}

	public static function rotationByFloat(x1:Float, y1:Float, x2:Float, y2:Float):Float {
		var angle = radianByFloat(x1, y1, x2, y2);
		return angle * 180 / Math.PI;
	}

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
