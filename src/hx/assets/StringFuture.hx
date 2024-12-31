package hx.assets;

#if openfl
typedef StringFuture = hx.core.StringFuture;
#else
class StringFuture extends Future<String, String> {}
#end
