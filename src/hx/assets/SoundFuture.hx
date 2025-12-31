package hx.assets;

#if openfl
typedef SoundFuture = hx.core.SoundFuture;
#else
class SoundFuture extends Future<Sound, String> {
	public var isMusic:Bool = false;
}
#end
