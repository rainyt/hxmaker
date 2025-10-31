package hx.utils;

class KeyboardTools {
	private static var __keys:Map<Int, Bool> = [];

	private static function onKeyDown(key:Int):Void {
		__keys.set(key, true);
		if (onKeyDownEvent != null)
			onKeyDownEvent(key);
	}

	private static function onKeyUp(key:Int):Void {
		__keys.set(key, false);
		if (onKeyUpEvent != null)
			onKeyUpEvent(key);
	}

	public static function isKeyDown(key:Int):Bool {
		return __keys.get(key);
	}

	public static function reset():Void {
		__keys = [];
	}

	public static var onKeyDownEvent:Int->Void;

	public static var onKeyUpEvent:Int->Void;
}
