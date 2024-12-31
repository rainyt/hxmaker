package hx.assets;

/**
 * XML资源解析器
 */
class XmlFuture extends Future<Xml, String> {
	override function post() {
		new StringFuture(this.getLoadData()).onComplete((text) -> {
			this.completeValue(Xml.parse(text));
		}).onError(this.errorValue);
	}
}
