package hx.utils;

class KeyboardTools {
	private static var __keys:Map<Int, Bool> = [];

	private static function onKeyDown(key:Int):Void {
		__keys.set(key, true);
	}

	private static function onKeyUp(key:Int):Void {
		__keys.set(key, false);
	}

	public static function isKeyDown(key:Int):Bool {
		return __keys.get(key);
	}

	public static function reset():Void {
		__keys = [];
	}
}
