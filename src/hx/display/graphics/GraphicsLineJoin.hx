package hx.display.graphics;

/** 路径描边的转角形状。 */
enum abstract GraphicsLineJoin(String) to String {
	var MITER = "miter";
	var BEVEL = "bevel";
	var ROUND = "round";
}
