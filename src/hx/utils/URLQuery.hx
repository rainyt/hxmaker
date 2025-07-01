package hx.utils;

/**
 * 用于解析url的参数使用 ?key=value1&key2=value2
 */
class URLQuery {
	/**
	 * 解析url的参数
	 * @param url 
	 * @return Map<String,String>
	 */
	public static function parse(url:String):Map<String, String> {
		var map:Map<String, String> = [];
		var param = url.substr(url.lastIndexOf("?") + 1);
		var array = param.split("&");
		for (item in array) {
			if (item.indexOf("=") != -1) {
				var p = item.split("=");
				map.set(p[0], p.slice(1).join("="));
			}
		}
		return map;
	}
}
