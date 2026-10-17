package;

class MetricClock {
	public static function now():Float {
		#if (js && html5)
		return js.Browser.window.performance.now();
		#else
		return haxe.Timer.stamp()*1000;
		#end
	}
}
