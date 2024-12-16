package hx.gemo;

/**
	* Matrix类表示一个转换矩阵，它决定了如何
	将点从一个坐标空间映射到另一个。您可以执行各种
	通过设置以下属性对显示对象进行图形转换
	一个Matrix对象，将该Matrix对象应用于
	变换对象，然后将该变换对象应用为
	`transform”显示对象的属性。这些转换函数
	包括平移（x和y重新定位）、旋转、缩放和
	歪斜。
	这些类型的转换统称为_affine
	转变_。仿射变换保持了
	在变换时，使平行线保持平行。
 */
class Matrix {
	/**
		影响像素沿_x_轴定位的值当缩放或旋转图像时。
	**/
	public var a:Float;

	/**
		影响像素沿_y_轴定位的值当旋转或倾斜图像时。
	**/
	public var b:Float;

	/**
		影响像素沿_x_轴定位的值当旋转或倾斜图像时。
	**/
	public var c:Float;

	/**
		影响像素沿_y_轴定位的值当缩放或旋转图像时。
	**/
	public var d:Float;

	/**
		沿_x_轴平移每个点的距离。
	**/
	public var tx:Float;

	/**
		沿_y_轴平移每个点的距离。
	**/
	public var ty:Float;

	public function new(a:Float = 1, b:Float = 0, c:Float = 0, d:Float = 1, tx:Float = 0, ty:Float = 0) {
		this.a = a;
		this.b = b;
		this.c = c;
		this.d = d;
		this.tx = tx;
		this.ty = ty;
	}

	public function clone():Matrix {
		return new Matrix(a, b, c, d, tx, ty);
	}

	public function concat(m:Matrix):Void {
		var a1 = a * m.a + b * m.c;
		b = a * m.b + b * m.d;
		a = a1;

		var c1 = c * m.a + d * m.c;
		d = c * m.b + d * m.d;
		c = c1;

		var tx1 = tx * m.a + ty * m.c + m.tx;
		ty = tx * m.b + ty * m.d + m.ty;
		tx = tx1;
	}

	public function copyFrom(sourceMatrix:Matrix):Void {
		a = sourceMatrix.a;
		b = sourceMatrix.b;
		c = sourceMatrix.c;
		d = sourceMatrix.d;
		tx = sourceMatrix.tx;
		ty = sourceMatrix.ty;
	}

	public function scale(sx:Float, sy:Float):Void {
		/*

			Scale object "after" other transforms

			[  a  b   0 ][  sx  0   0 ]
			[  c  d   0 ][  0   sy  0 ]
			[  tx ty  1 ][  0   0   1 ]
		**/

		a *= sx;
		b *= sy;
		c *= sx;
		d *= sy;
		tx *= sx;
		ty *= sy;

		// __cleanValues ();
	}

	public function rotate(theta:Float):Void {
		/**
			Rotate object "after" other transforms

			[  a  b   0 ][  ma mb  0 ]
			[  c  d   0 ][  mc md  0 ]
			[  tx ty  1 ][  mtx mty 1 ]

			ma = md = cos
			mb = sin
			mc = -sin
			mtx = my = 0
		**/

		var cos = Math.cos(theta);

		var sin = Math.sin(theta);

		var a1 = a * cos - b * sin;
		b = a * sin + b * cos;
		a = a1;

		var c1 = c * cos - d * sin;
		d = c * sin + d * cos;
		c = c1;

		var tx1 = tx * cos - ty * sin;
		ty = tx * sin + ty * cos;
		tx = tx1;

		// __cleanValues ();
	}

	public function identity():Void {
		a = 1;
		b = 0;
		c = 0;
		d = 1;
		tx = 0;
		ty = 0;
	}

	public function translate(dx:Float, dy:Float):Void {
		tx += dx;
		ty += dy;
	}
}
