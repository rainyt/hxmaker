package hx.utils;

/**
 * 缩放比例工具
 */
class ScaleUtils {
	public static function mathScale(stageWidth:Float, stageHeight:Float, hdwidth:Float, hdheight:Float, lockLandscape:Bool = false,
			scalePower:Bool = false):Float {
		var currentScale:Float = 1;

		if (hdwidth == 0 || hdheight == 0) {
			return currentScale;
		}

		var wscale:Float = 1;
		var hscale:Float = 1;
		if (lockLandscape && stageWidth < stageHeight) {
			hscale = Math.round(stageWidth / hdheight * 1000000) / 1000000;
			wscale = Math.round(stageHeight / hdwidth * 1000000) / 1000000;
		} else {
			wscale = Math.round(stageWidth / hdwidth * 1000000) / 1000000;
			hscale = Math.round(stageHeight / hdheight * 1000000) / 1000000;
		}
		if (hdwidth > hdheight) {
			if (wscale > hscale) {
				currentScale = wscale;
			} else {
				currentScale = hscale;
			}
		} else {
			if (wscale < hscale) {
				currentScale = wscale;
			} else {
				currentScale = hscale;
			}
		}

		if (scalePower) {
			var currentScaleCounts = Std.int(currentScale / 0.5);
			if (currentScaleCounts <= 0)
				currentScaleCounts++;
			currentScale = currentScaleCounts * 0.5;
		}

		return currentScale;
	}
}
