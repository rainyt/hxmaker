package hx.assets;

#if (openfl || hxmaker_unity)
typedef BitmapDataFuture = hx.core.BitmapDataFuture;
#else
import hx.display.BitmapData;

class BitmapDataFuture extends Future<BitmapData, String> {}
#end
