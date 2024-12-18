package hx.utils;

#if openfl
typedef BitmapDataFuture = hx.core.BitmapDataFuture;
#else
import hx.displays.BitmapData;

class BitmapDataFuture extends Future<BitmapData, String> {}
#end
