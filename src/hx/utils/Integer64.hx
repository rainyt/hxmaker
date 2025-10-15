package hx.utils;

import haxe.Exception;
import haxe.Int64;

using StringTools;

/**
 * 用于支持Int64位 
 */
@:using(hx.utils.Integer64.Integer64Tools)
typedef Integer64 = Int64;

class Integer64Tools {
	/**
	 * 乘法
	 * @param v 
	 * @param f 
	 * @return Integer64
	 */
	public static function mul(v:Int64, f:Float):Integer64 {
		var f = Std.parseFloat(@:privateAccess v.toString()) * f;
		var v = Std.string(f);
		var eindex = v.indexOf("e+");
		if (eindex != -1) {
			var e = v.substr(eindex + 2);
			var len = Std.parseInt(e) - 1;
			v = v.substr(0, eindex);
			v = v.replace(".", "");
			len -= Std.string(v).length;
			len += 2;
			for (i in 0...len) {
				v += "0";
			}
		} else {
			v = Std.string(f);
			var d = v.indexOf(".");
			if (d != -1)
				v = v.substr(0, d);
		}
		try {
			return Int64.parseString(v);
		} catch (e:Exception) {
			return 0;
		}
	}

	/**
	 * 保留浮点的除法处理
	 * @param v 
	 * @param v2 
	 * @return Float
	 */
	public static function div(v:Int64, v2:Int64):Float {
		var f1 = toFloat(v);
		var f2 = toFloat(v2);
		return f1 / f2;
	}

	/**
	 * 转换为浮点数
	 * @param v 
	 * @return Float
	 */
	public static function toFloat(v:Int64):Float {
		var f = Std.parseFloat(@:privateAccess v.toString());
		return f;
	}

	/**
	 * 转换为Int
	 * @param v 
	 * @return Int
	 */
	public static function toInt(v:Int64):Int {
		try {
			return Int64.toInt(v);
		} catch (e:Exception) {
			return 0;
		}
	}

	/**
	 * 将Int64转换为字符串
	 * @param v 
	 * @return String
	 */
	public static function str(v:Int64):String {
		return Int64.toStr(v);
	}
}
