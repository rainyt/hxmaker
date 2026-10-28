package hx.assets;

#if (openfl || hxmaker_unity)
typedef BytesFuture = hx.core.BytesFuture;
#else
import haxe.io.Bytes;

class BytesFuture extends Future<Bytes, String> {}
#end
