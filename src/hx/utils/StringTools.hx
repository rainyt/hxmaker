package hx.utils;

import StringTools in StringToolsCore;

using haxe.io.Path;

/**
 * 字符串工具
 */
class StringTools {
	/**
	 * 删除所有扩展名和路径，只提取文件名称
	 * @param str 
	 * @return String
	 */
	public static function getName(str:String):String {
		return str.withoutDirectory().withoutExtension();
	}

	/**
	 * 替换字符串
	 * @param str 
	 * @param old 
	 * @param new 
	 * @return String
	 */
	public static function replace(str:String, old:String, r:String):String {
		return StringToolsCore.replace(str, old, r);
	}
}
