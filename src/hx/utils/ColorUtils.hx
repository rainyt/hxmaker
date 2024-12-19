package hx.utils;

/**
 * 颜色工具
 */
class ColorUtils {
	/**
	 * 转换为Shader使用的-1~1的浮点数值，支持`0xFFFFFF`、`#FFFFFF`等颜色格式。
	 * @param color 
	 * @return Color
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

typedef Color = {
	r:Float,
	g:Float,
	b:Float
}
