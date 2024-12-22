package hx.utils;

#if openfl
typedef BitmapDataFuture = hx.core.BitmapDataFuture;
#else
import hx.display.BitmapData;

class BitmapDataFuture extends Future<BitmapData, String> {}
#end
