package hx.utils;

import hx.display.DisplayObject;

using StringTools;

class XmlTools {
	/**
	 * 获得xml中的属性浮点值
	 * @param xml 
	 * @param key 
	 * @return Null<Float>
	 */
	public static function getFloatValue(xml:Xml, key:String):Null<Float> {
		if (xml.exists(key) == false) {
			return null;
		}
		var value = xml.get(key);
		if (value.indexOf("%") != -1) {
			// 百分比计算
			return Std.parseFloat(value.replace("%", ""));
		}
		return Std.parseFloat(xml.get(key));
	}
}
