package;

import hx.display.BlendMode;

/** 在不透明背景上计算直通 RGB 的参考色，不调用引擎混合或离屏绘制。 */
class BlendReference {
	public static function composite(destination:Int, source:Int, alpha:Float, mode:BlendMode):Int {
		var result = 0;
		for (index in 0...3) {
			var shift = (2 - index) * 8;
			var back = ((destination >> shift) & 255) / 255.0;
			var front = ((source >> shift) & 255) / 255.0;
			var mixed = switch mode {
				case NORMAL: front;
				case MULTIPLY: back * front;
				case SCREEN: 1 - (1 - back) * (1 - front);
				case DIFFERENCE: Math.abs(back - front);
				case SUBTRACT: Math.max(0, back - front);
				case INVERT: 1 - back;
				case DARKEN: Math.min(back, front);
				case LIGHTEN: Math.max(back, front);
				case HARDLIGHT: front <= 0.5 ? 2 * back * front : 1 - 2 * (1 - back) * (1 - front);
				case OVERLAY: back <= 0.5 ? 2 * back * front : 1 - 2 * (1 - back) * (1 - front);
				case ADD: front;
				default: throw "该模式没有通用 RGB 参考公式：" + mode;
			};
			// 加法先乘源透明度再饱和；其余模式在混合色与背景之间插值。
			var value = mode == ADD ? back + front * alpha : back + (mixed - back) * alpha;
			result |= Math.round(Math.max(0, Math.min(1, value)) * 255) << shift;
		}
		return result;
	}

	public static function checker(x:Int, y:Int):Int {
		return (Std.int(x / 8) + Std.int(y / 8)) % 2 == 0 ? 0x34465e : 0x9aabc0;
	}

	/** 透明边框与四档透明度同时覆盖零、部分和完全覆盖的纹理像素。 */
	public static function maskAlpha(x:Int, y:Int):Int {
		if (x < 8 || x >= 104 || y < 8 || y >= 56)
			return 0;
		return Std.int((x - 8) / 24) * 85;
	}
}
