package hx.display;

/**
 * 方向
 */
enum abstract Direction(Int) to Int from Int {
	/**
	 * 横向
	 */
	public var HORIZONTAL = 0;

	/**
	 * 纵向
	 */
	public var VERTICAL = 1;
}
