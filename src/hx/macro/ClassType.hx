package hx.macro;

import hx.display.DisplayObject;

/**
 * 已定义的类型模块
 */
class MClassType {
	/**
	 * 当前模块的类名
	 */
	public var className:String;

	/**
	 * 类型绑定
	 */
	public var attributes:Map<String, Attributes>;

	public function new(xml:Xml) {
		className = xml.get("classed");
		for (item in xml.elements()) {
			attributes.set(item.nodeName, new Attributes(item));
		}
	}
}

/**
 * 属性绑定
 */
class Attributes {
	/**
	 * 属性类型
	 */
	public var type:AttributesType;

	/**
	 * 属性键值
	 */
	public var key:String;

	public function new(xml:Xml) {
		key = xml.nodeName;
		type = xml.get("type");
	}

	/**
	 * 绑定数据值
	 * @param display 
	 * @param value 
	 */
	public function setValue(display:DisplayObject, value:String):Void {
		switch type {
			case STRING:
				Reflect.setProperty(display, key, value);
		}
	}
}

enum abstract AttributesType(String) to String from String {
	var STRING = "String";
}
