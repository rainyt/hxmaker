package hx.macro;

/**
 * 已定义的类型模块
 */
class MoudleClassType {
	/**
	 * 当前模块的类名
	 */
	public var className:String;

	/**
	 * 当前模块的继承类名
	 */
	public var extendsClassName:String;

	/**
	 * 类型绑定
	 */
	public var attributes:Map<String, Attributes> = [];

	public function new(?xml:Xml, ?className:String) {
		if (xml != null) {
			className = xml.get("classed");
			extendsClassName = xml.get("extends");
			for (item in xml.elements()) {
				attributes.set(item.nodeName, new Attributes(item));
			}
		}
		if (className != null)
			this.className = className;
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
	public function setValue(display:Dynamic, value:String):Void {
		switch type {
			case STRING:
				Reflect.setProperty(display, key, value);
		}
	}
}

enum abstract AttributesType(String) to String from String {
	var STRING = "String";
}
