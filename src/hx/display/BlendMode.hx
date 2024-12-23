package hx.display;

/**
 * 为视觉混合模式效果提供常数值的类。
 */
enum abstract BlendMode(String) to String from String {
	/**
	 * 将显示对象的颜色值添加到其背景的颜色中
	 */
	var ADD = "add";

	/**
	 * 将显示对象颜色的值和背景颜色相乘。
	 */
	var MULTIPLY = "multiply";

	/**
	 * 显示对象出现在背景前面。
	 */
	var NORMAL = "normal";

	/**
	 * 将显示对象颜色的补色（反转）与背景颜色的补品相乘，从而产生漂白效果。
	 */
	var SCREEN = "screen";
}
