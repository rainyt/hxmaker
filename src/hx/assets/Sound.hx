package hx.assets;

class Sound {
	public var root:ISound;

	public function new() {}

	/**
	 * 按指定音量播放资源。后端可重写此入口，在创建声道时应用音量。
	 * 默认实现保留现有后端的播放流程，不要求修改 ISound。
	 */
	public function play(isLoop:Bool = false, volume:Float = 1.0, pan:Float = 0.0):ISoundChannel {
		var channel:ISoundChannel = root.play(isLoop);
		if (channel != null) {
			channel.setVolume(volume, pan);
		}
		return channel;
	}
}
