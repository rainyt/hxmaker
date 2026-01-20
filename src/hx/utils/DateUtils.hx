package hx.utils;

import haxe.Exception;

using hx.utils.StringTools;

/**
 * 时间工具
 */
class DateUtils {
	/**
	 * 兼容多种格式
	 * 2021-09-29T02:31:56.583Z
	 * 2022-01-16 04:03:53Z
	 * 2021-09-29 02:31:56
	 * @param string 
	 * @return Date
	 */
	public static function fromString(string:String):Date {
		if (string == null)
			return null;
		try {
			var newstr = string.substr(0, 10);
			newstr += " " + string.substr(11, 8);
			var date = Date.fromString(newstr);
			return date;
		} catch (e:Exception) {
			return null;
		}
	}

	/**
	 * 获取明天的时间的字符串格式2001-10-1 00:00:00
	 * @param curDate 当前时间
	 * @param time 明天的时间，格式为00:00:00
	 * @return String
	 */
	public static function getTomorrowDateString(curDate:Date, time:String):String {
		var newDate = Date.fromTime(curDate.getTime() + 24 * 60 * 60 * 1000);
		return '${DateTools.format(newDate, "%Y-%m-%d")} ' + time;
	}

	/**
		根据年月日获得时间戳
	**/
	public static function fromDate(year:Int, m:Int, d:Int, h:Int, f:Int):Date {
		var format = '${year}-${zero(m)}-${zero(d)} ${zero(h)}:${zero(f)}:00';
		var date = Date.fromString(format);
		return date;
	}

	public static function zero(i:Int):String {
		return i < 10 ? "0" + i : Std.string(i);
	}

	/**
	 * 格式化日期
	 * %Y 年
	 * %m 月
	 * %d 日
	 * %H 时
	 * %M 分
	 * %S 秒
	 */
	public static function formatDate(?date:String, format:String = "%Y-%m-%d %H:%M:%S"):String {
		if (date == null)
			return "";
		var date = fromString(date);
		var year = date.getFullYear();
		var month = date.getMonth() + 1;
		var day = date.getDate();
		var hour = date.getHours();
		var minute = date.getMinutes();
		var second = date.getSeconds();
		return format.replace("%Y", Std.string(year))
			.replace("%m", Std.string(month))
			.replace("%d", Std.string(day))
			.replace("%H", Std.string(hour))
			.replace("%M", Std.string(minute))
			.replace("%S", Std.string(second));
	}
}
