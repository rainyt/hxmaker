package hx.media;

class SoundTransform {
	public var volume:Float = 1;
	public var pan:Float = 0;
	public var leftVolume:Float = 1;
	public var rightVolume:Float = 1;

	public function new(volume:Float = 1.0, pan:Float = 0.0) {
		this.volume = volume;
		this.pan = pan;
		this.leftVolume = volume * (1 - pan);
		this.rightVolume = volume * (1 + pan);
	}
}
