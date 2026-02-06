package hx.utils;

import hx.utils.StringTools;

/**
 * 颜色工具类，提供颜色转换和处理的常用方法
 */
class ColorUtils {
	/**
	 * 将颜色值转换为Shader使用的浮点数值（0~1范围）
	 * 支持多种颜色格式：
	 * - 十六进制数值：0xFFFFFF
	 * - 十六进制字符串："#FFFFFF"
	 * @param color 颜色值，可以是数值或字符串
	 * @return 转换后的Color对象，包含r、g、b三个通道的浮点值
	 */
	public static function toShaderColor(color:Dynamic):Color {
		if (color is String) {
			var value = StringTools.replace(color, "#", "0x");
			color = Std.parseInt(value);
		}
		var r = (color >> 16) & 0xFF;
		var g = (color >> 8) & 0xFF;
		var b = color & 0xFF;
		return {
			r: r / 255,
			g: g / 255,
			b: b / 255
		};
	}
}

/**
 * 颜色类型定义，包含RGB三个通道的浮点值（0~1范围）
 */
typedef Color = {
	/** 红色通道值，范围0~1 */
	r:Float,
	/** 绿色通道值，范围0~1 */
	g:Float,
	/** 蓝色通道值，范围0~1 */
	b:Float
}
