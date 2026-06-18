package hx.assets;

/**
 * zip包加载支持
 */
class ZipFuture extends Future<Zip, String> {
	override function post() {
		super.post();
		new BytesFuture(getLoadData()).onComplete(data -> {
			this.addAssetObject(data);
			var zip = new Zip(data.data);
			this.completeValue(zip);
		}).onError(this.errorValue);
	}
}
