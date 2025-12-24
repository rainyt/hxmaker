package hx.display;

/**
 * 为视觉混合模式效果提供常数值的类。
 */
enum abstract BlendMode(String) to String from String {
	/**
	 * 将显示对象的颜色值添加到其背景的颜色中
	 * - 加法滤镜在Hxmaker中得到支持
	 */
	var ADD = "add";

	/**
	 * 将显示对象颜色的值和背景颜色相乘。
	 * - 乘法滤镜在Hxmaker中得到支持
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

	/**
		将显示对象的组成颜色与以下颜色进行比较
		它的背景，并减去两者中较暗的值
		从较浅的值中提取组成颜色。此设置常用
		以获得更鲜艳的颜色。
		例如，如果显示对象具有RGB值为的像素
		0xFFCC33，背景像素的RGB值为0xDDF800
		显示像素的RGB值为0x222C33（因为0xFF-
		0xDD=0x22，0xF8-0xCC=0x2C，0x33-0x00=0x33）。
		- 差异滤镜在Hxmaker中得到支持
	 */
	var DIFFERENCE = "difference";

	/**
	 * 从背景色的值中减去显示对象中组成颜色的值，应用0的下限。此设置通常用于为两个对象之间的暗化溶解设置动画。<br>例如，如果显示对象具有RGB值为0xAA2233的像素，而背景像素具有RGB值0xDDA600，则显示像素的最终RGB值是0x338400（因为0xDD-0xAA=0x33，0xA6-0x22=0x84，以及0x00-0x33<0x00）。
	 * - 相减滤镜在Hxmaker中得到支持
	 */
	var SUBTRACT = "subtract";

	/**
	 * 翻转颜色
	 * - 翻转滤镜在Hxmaker中得到支持
	 */
	var INVERT = "invert";

	/**
		选择显示对象的组成颜色中较深的颜色
		背景的颜色（值较小的颜色）。这
		设置通常用于叠加类型。
		例如，如果显示对象具有RGB值为的像素
		0xFFCC33，背景像素的RGB值为0xDDF800
		显示像素的RGB值为0xDDCC00（因为0xFF>
		0xDD、0xCC＜0xF8和0x33＞0x00＝33）。
		- 变暗滤镜在Hxmaker中得到支持
	 */
	var DARKEN = "darken";

	/**
		选择显示对象的组成颜色中较浅的颜色
		背景的颜色（值较大的颜色）。这
		设置通常用于叠加类型。
		例如，如果显示对象具有RGB值为的像素
		0xFFCC33，背景像素的RGB值为0xDDF800
		显示像素的RGB值为0xFFF833（因为0xFF<
		0xDDF8、0xCC>0xF8和0x33<0x00＝33）。
		- 变亮滤镜在Hxmaker中得到支持
	 */
	var LIGHTEN = "lighten";
}
