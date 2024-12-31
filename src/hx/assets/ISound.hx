package hx.assets;

interface ISound {
	public function dispose():Void;

	public function play(isLoop:Bool = false):ISoundChannel;
}
