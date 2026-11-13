package hx.events;

/**
 * 音乐事件
 */
class SoundEvent extends Event {
	/**
	 * 音乐播放完成时触发
	 */
	public inline static var SOUND_COMPLETE = "sound_complete";

	/**
	 * 声道被主动停止或循环重播失败时触发，用于清理声道跟踪。
	 */
	public inline static var SOUND_STOP:String = "sound_stop";

	/**
	 * 转换为字符串表示
	 * @return 声音事件的字符串描述
	 */
	public override function toString():String {
		return "SoundEvent[type=" + type + "]";
	}
}
