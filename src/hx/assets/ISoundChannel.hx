package hx.assets;

import hx.display.IEventDispatcher;

interface ISoundChannel extends IEventDispatcher {
	public function stop():Void;

	public function setVolume(volume:Float, pan:Float = 0.0):Void;
}
