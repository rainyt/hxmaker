package hx.layout;

/**
 * 
 */
class AnchorLayoutData extends LayoutData {
	/**
	 * 居中配置
	 * @param x 
	 * @param y 
	 * @return AnchorLayoutData
	 */
	public static function center(x:Null<Float> = 0.0, y:Null<Float> = 0.0):AnchorLayoutData {
		return new AnchorLayoutData(null, null, null, null, x, y);
	}

	/**
	 * 填满
	 * @param padding 
	 * @return AnchorLayoutData
	 */
	public static function fill(padding:Float = 0.0):AnchorLayoutData {
		return new AnchorLayoutData(padding, padding, padding, padding);
	}

	/**
	 * 填满竖向
	 * @param padding 
	 * @return AnchorLayoutData
	 */
	public static function fillHorizontal(padding:Float = 0.0):AnchorLayoutData {
		return new AnchorLayoutData(null, padding, null, padding);
	}

	/**
	 * 填满横向
	 * @param padding 
	 * @return AnchorLayoutData
	 */
	public static function fillVertical(padding:Float = 0.0):AnchorLayoutData {
		return new AnchorLayoutData(padding, null, padding, null);
	}

	public static function topLeft(top:Float = 0.0, left:Float = 0.0) {
		return new AnchorLayoutData(top, null, null, left);
	}

	public static function topCenter(top:Float = 0.0, horizontalCenter:Float = 0.0) {
		return new AnchorLayoutData(top, null, null, null, horizontalCenter);
	}

	public static function topRight(top:Float = 0.0, right:Float = 0.0) {
		return new AnchorLayoutData(top, right);
	}

	public static function middleLeft(verticalCenter:Float = 0.0, left:Float = 0.0) {
		return new AnchorLayoutData(null, null, null, left, null, verticalCenter);
	}

	public static function middleRight(verticalCenter:Float = 0.0, right:Float = 0.0) {
		return new AnchorLayoutData(null, right, null, null, null, verticalCenter);
	}

	public static function bottomLeft(bottom:Float = 0.0, left:Float = 0.0) {
		return new AnchorLayoutData(null, null, bottom, left);
	}

	public static function bottomCenter(bottom:Float = 0.0, horizontalCenter:Float = 0.0) {
		return new AnchorLayoutData(null, null, bottom, null, horizontalCenter);
	}

	public static function bottomRight(bottom:Float = 0.0, right:Float = 0.0) {
		return new AnchorLayoutData(null, right, bottom);
	}

	/**
	 * 左
	 */
	public var left:Null<Float> = null;

	/**
	 * 右
	 */
	public var right:Null<Float> = null;

	/**
	 * 上
	 */
	public var top:Null<Float> = null;

	/**
	 * 下
	 */
	public var bottom:Null<Float> = null;

	/**
	 * 居中X
	 */
	public var horizontalCenter:Null<Float> = null;

	/**
	 * 垂直Y
	 */
	public var verticalCenter:Null<Float> = null;

	public function new(?top:Float, ?right:Float, ?bottom:Float, ?left:Float, ?horizontalCenter:Null<Float>, ?verticalCenter:Null<Float>) {
		super();
		this.top = top;
		this.right = right;
		this.bottom = bottom;
		this.left = left;
		this.horizontalCenter = horizontalCenter;
		this.verticalCenter = verticalCenter;
	}
}
