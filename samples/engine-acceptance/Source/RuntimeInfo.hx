package;

import hx.core.Hxmaker;
import hx.utils.ContextStats;

class RuntimeInfo {
	public static function hidden():Bool {
		#if (js && html5)
		return js.Browser.document.hidden;
		#else
		return false;
		#end
	}
	public static function sizeKey():String {
		#if (js && html5)
		return js.Browser.window.innerWidth+":"+js.Browser.window.innerHeight+":"+js.Browser.window.devicePixelRatio;
		#else
		return Hxmaker.engine.stageWidth+":"+Hxmaker.engine.stageHeight+":"+Hxmaker.engine.devicePixelRatio;
		#end
	}
	public static function heap():Null<Float> {
		#if (js && html5)
		var memory:Dynamic = Reflect.field(js.Browser.window.performance,"memory");
		if (memory != null) {
			var used:Dynamic = Reflect.field(memory,"usedJSHeapSize");
			if (used != null) return used;
		}
		#end
		return null;
	}
	/** 只在场景建立与报告导出时查询环境，不进入逐帧 GL 采样。 */
	public static function environment():Dynamic {
		var result:Dynamic = {createdAt:Date.now().toString(),stageWidth:Hxmaker.engine.stageWidth,stageHeight:Hxmaker.engine.stageHeight,
			devicePixelRatio:Hxmaker.engine.devicePixelRatio,targetFrameRate:Hxmaker.engine.frameRate,
			platform:"原生",versionLabel:BuildInfo.label(),versions:BuildInfo.versions(),heapAvailable:heap() != null};
		#if (js && html5)
		result.platform = "HTML5"; result.userAgent = js.Browser.navigator.userAgent;
		result.windowWidth = js.Browser.window.innerWidth; result.windowHeight = js.Browser.window.innerHeight;
		result.browserDpr = js.Browser.window.devicePixelRatio;
		try {
			var gl:Dynamic = openfl.Lib.current.stage.window.context.webgl;
			if (gl != null && !gl.isContextLost()) result.gl = {version:gl.getParameter(gl.VERSION),renderer:gl.getParameter(gl.RENDERER),
				vendor:gl.getParameter(gl.VENDOR),maxTextureUnits:gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS),maxTextureSize:gl.getParameter(gl.MAX_TEXTURE_SIZE),
				canvasWidth:gl.canvas.width,canvasHeight:gl.canvas.height};
		} catch (_:Dynamic) {}
		#end
		return result;
	}
	public static function resources():Dynamic {
		return {atMs:MetricClock.now(),references:ContextStats.totalRefCount,cacheEntries:ContextStats.totalCacheCount,jsHeapBytes:heap()};
	}
}
