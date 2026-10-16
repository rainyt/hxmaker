package hx.assets;

#if openfl
typedef BitmapDataBytesFuture = hx.core.BitmapDataBytesFuture;
#else
import haxe.io.Bytes;
import hx.display.BitmapData;
import hx.events.FutureErrorEvent;

/** 非 OpenFL 后端需实现图片字节解码，不发起额外网络请求。 */
class BitmapDataBytesFuture extends Future<BitmapData, {bytes:Bytes, path:String}> {
	override public function post():Void {
		errorValue(FutureErrorEvent.create(FutureErrorEvent.LOAD_ERROR, -1, "当前后端尚未实现图片字节解码"));
	}
}
#end
