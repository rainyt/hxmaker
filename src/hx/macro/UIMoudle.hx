package hx.macro;

class UIMoudle {
	public var classed:Map<String, String> = [];

	public function new(xml:Xml) {
		for (item in xml.firstElement().elements()) {
			classed.set(item.nodeName, item.get("classed"));
		}
	}

	public function getType(type:String):String {
		if (type.indexOf("xml:") == 0) {
			type = StringTools.replace(type, "xml:", "");
		}
		if (classed.exists(type)) {
			return classed.get(type);
		}
		return "hx.display." + type;
	}
}
