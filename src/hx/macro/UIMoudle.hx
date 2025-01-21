package hx.macro;

/**
 * UI模块数据
 */
class UIMoudle {
	/**
	 * 已定义的类型绑定
	 */
	public var classed:Map<String, MoudleClassType> = [];

	public function new(content:String) {
		if (content == null) {
			return;
		}
		var xml = Xml.parse(content);
		for (item in xml.firstElement().elements()) {
			classed.set(item.nodeName, new MoudleClassType(item));
		}
	}

	/**
	 * 查询是否存在组件类型
	 * @param type 
	 * @return String
	 */
	public function getType(type:String):String {
		if (type.indexOf("xml:") == 0) {
			type = StringTools.replace(type, "xml:", "");
		}
		if (classed.exists(type)) {
			return classed.get(type).className;
		}
		return "hx.display." + type;
	}

	public function getClassType(c:Dynamic):MoudleClassType {
		var cName = Type.getClassName(Type.getClass(c));
		if (cName == null)
			return null;
		cName = cName.split(".").pop();
		if (classed.exists(cName))
			return classed.get(cName);
		return null;
	}
}
