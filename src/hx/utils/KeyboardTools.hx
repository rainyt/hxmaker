package hx.utils;

import haxe.Timer;

class KeyboardTools {
	private static var __keys:Map<Int, Bool> = [];

	private static var _upKeys:Map<Int, Float> = [];

	private static function onKeyDown(key:Int):Void {
		__keys.set(key, true);
		_upKeys.set(key, Timer.stamp());
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

	/**
	 * 当松开了某个键时，则算点击了一次
	 * @param bind 
	 * @param key 
	 * @return Bool
	 */
	public static function isKeyClick(key:Int):Bool {
		if (_upKeys.exists(key)) {
			var time = Timer.stamp() - _upKeys.get(key);
			_upKeys.remove(key);
			if (time < 0.3) {
				return true;
			}
		}
		return false;
	}

	public static function reset():Void {
		__keys = [];
		_upKeys = [];
	}

	public static var onKeyDownEvent:Int->Void;

	public static var onKeyUpEvent:Int->Void;
}
