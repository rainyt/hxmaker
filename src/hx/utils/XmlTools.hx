package hx.utils;

class XmlTools {
	public static function getFloatValue(xml:Xml, key:String):Null<Float> {
		if (xml.exists(key) == false) {
			return null;
		}
		return Std.parseFloat(xml.get(key));
	}
}
