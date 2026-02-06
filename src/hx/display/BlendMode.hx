package hx.display;

/**
 * 为视觉混合模式效果提供常数值的类
 * 定义了各种混合模式，用于控制显示对象如何与背景混合
 */
enum abstract BlendMode(String) to String from String {
	/**
	 * 将显示对象的颜色值添加到其背景的颜色中
	 * 产生更亮的效果，常用于发光、粒子效果等
	 * - 加法滤镜在Hxmaker中得到支持
	 */
	var ADD = "add";

	/**
	 * 将显示对象颜色的值和背景颜色相乘
	 * 产生更暗的效果，常用于阴影、遮罩等
	 * - 乘法滤镜在Hxmaker中得到支持
	 */
	var MULTIPLY = "multiply";

	/**
	 * 正常混合模式
	 * 显示对象出现在背景前面，不进行特殊混合
	 */
	var NORMAL = "normal";

	/**
	 * 将显示对象颜色的补色与背景颜色的补色相乘
	 * 产生漂白效果，常用于高光、反光等
	 */
	var SCREEN = "screen";

	/**
	 * 比较显示对象和背景的颜色，减去较暗的值
	 * 从较浅的值中，产生更鲜艳的颜色效果
	 * 例如，如果显示对象具有RGB值为0xFFCC33的像素，背景像素的RGB值为0xDDF800
	 * 显示像素的RGB值为0x222C33（因为0xFF-0xDD=0x22，0xF8-0xCC=0x2C，0x33-0x00=0x33）
	 * - 差异滤镜在Hxmaker中得到支持
	 */
	var DIFFERENCE = "difference";

	/**
	 * 从背景色的值中减去显示对象中组成颜色的值，应用0的下限
	 * 通常用于为两个对象之间的暗化溶解设置动画
	 * 例如，如果显示对象具有RGB值为0xAA2233的像素，而背景像素具有RGB值0xDDA600
	 * 显示像素的最终RGB值是0x338400（因为0xDD-0xAA=0x33，0xA6-0x22=0x84，以及0x00-0x33<0x00）
	 * - 相减滤镜在Hxmaker中得到支持
	 */
	var SUBTRACT = "subtract";

	/**
	 * 快速减法混合模式
	 * 对应`BlendMode.SUBTRACT_FAST`，更快但效果略有不同
	 * 背景色会固定为`vec4(0.5)`
	 */
	var SUBTRACT_FAST = "subtract_fast";

	/**
	 * 翻转颜色
	 * 将显示对象的颜色与背景颜色进行反转混合
	 * - 翻转滤镜在Hxmaker中得到支持
	 */
	var INVERT = "invert";

	/**
	 * 选择显示对象和背景中较深的颜色
	 * 适用于需要强调暗部细节的场景
	 * 例如，如果显示对象具有RGB值为0xFFCC33的像素，背景像素的RGB值为0xDDF800
	 * 显示像素的RGB值为0xDDCC00（因为0xFF>0xDD、0xCC＜0xF8和0x33＞0x00＝33）
	 * - 变暗滤镜在Hxmaker中得到支持
	 */
	var DARKEN = "darken";

	/**
	 * 选择显示对象和背景中较浅的颜色
	 * 适用于需要强调亮部细节的场景
	 * 例如，如果显示对象具有RGB值为0xFFCC33的像素，背景像素的RGB值为0xDDF800
	 * 显示像素的RGB值为0xFFF833（因为0xFF>0xDD、0xCC<0xF8和0x33<0x00=33）
	 * - 变亮滤镜在Hxmaker中得到支持
	 */
	var LIGHTEN = "lighten";

	/**
	 * 强制为显示对象创建透明度组
	 * 意味着显示对象在被进一步处理之前已在临时缓冲区中预编译
	 * 如果显示对象是通过位图缓存预缓存的，或者如果显示对象是一个显示对象容器
	 * 它至少有一个子对象除了"正常"之外，还有"混合模式"设置，则预编译将自动完成
	 */
	var LAYER = "layer";

	/**
	 * 将显示对象的每个像素的alpha值应用于背景
	 * 这需要父显示对象的`blendMode`属性设置为`hx.display.BlendMode.LAYER`
	 */
	var ALPHA = "alpha";

	/**
	 * 将显示对象的每个像素的alpha值从背景中擦除
	 * 这需要父显示对象的`blendMode`属性设置为`hx.display.BlendMode.LAYER`
	 */
	var ERASE = "erase";

	/**
	 * 根据显示对象的暗度调整每个像素的颜色
	 * 如果显示对象比50%灰色亮，则背景颜色被屏蔽从而产生较浅的颜色
	 * 如果显示对象比50%灰色暗，则颜色会成倍增加，这导致颜色变深
	 * 此设置通常用于着色效果
	 */
	var HARDLIGHT = "hardlight";

	/**
	 * 根据背景的暗度调整每个像素的颜色
	 * 如果背景比50%灰色浅，则显示对象和背景颜色被屏蔽，导致颜色变浅
	 * 如果背景比50%灰色深，颜色会成倍增加，这导致颜色变深
	 * 此设置通常用于着色效果
	 */
	var OVERLAY = "overlay";
}
