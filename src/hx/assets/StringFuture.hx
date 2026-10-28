package hx.assets;

#if (openfl || hxmaker_unity)
typedef StringFuture = hx.core.StringFuture;
#else
class StringFuture extends Future<String, String> {}
#end
