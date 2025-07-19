package hx.utils;

class ArraySort {
	public static function sort(v:String, v2:String):Int {
		if (v.length > v2.length) {
			if (v.indexOf(v2) == 0) {
				return 1;
			}
		} else if (v.length < v2.length) {
			if (v2.indexOf(v) == 0) {
				return -1;
			}
		}
		for (i in 0...v.length) {
			if (i > v2.length) {
				return 1;
			} else {
				var a1:Int = v.charCodeAt(i);
				var a2:Int = v2.charCodeAt(i);
				if (a1 > a2)
					return 1;
				else if (a1 < a2)
					return -1;
			}
		}
		return -1;
	}
}
