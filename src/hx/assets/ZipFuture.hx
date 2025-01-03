package hx.assets;

/**
 * zip包加载支持
 */
class ZipFuture extends Future<Zip, String> {
	override function post() {
		super.post();
		new BytesFuture(getLoadData()).onComplete(data -> {
			var zip = new Zip(data);
			this.completeValue(zip);
		}).onError(this.errorValue);
	}
}
