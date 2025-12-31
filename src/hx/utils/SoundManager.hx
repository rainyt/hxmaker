package hx.utils;

import hx.events.SoundEvent;
import haxe.Timer;
import hx.ui.UIManager;
import hx.assets.ISoundChannel;
import hx.media.SoundTransform;

/**
 * 音频管理器
 */
class SoundManager {
	private static var __soundManager:SoundManager;

	/**
	 * 获得音频管理器单例
	 * @return SoundManager
	 */
	public static function getInstance():SoundManager {
		if (__soundManager == null) {
			__soundManager = new SoundManager();
		}
		return __soundManager;
	}

	private var __soundEffects:Map<String, Float> = [];

	private var __effectSoundChannel:Array<ISoundChannel> = [];

	/**
	 * 音效播放间隔，多个音效在同一个时间内播放时，不会重叠播放
	 */
	public var effectTimeInterval:Float = 0.06;

	private function new() {}

	/**
	 * 播放音效
	 * @param id 
	 * @param isLoop 是否循环播放
	 * @param isForce 是否强制播放
	 * @return ISoundChannel，该对象在不可播放的情况下会返回`null`
	 */
	public function playEffect(id:String, isLoop:Bool = false, isForce:Bool = false):ISoundChannel {
		var now = Timer.stamp();
		if (!isForce && __soundEffects.exists(id)) {
			if (now - __soundEffects.get(id) < effectTimeInterval) {
				return null;
			}
		}
		__soundEffects.set(id, now);
		var sound = UIManager.getSound(id);
		if (sound != null) {
			var channel = sound.root.play(isLoop);
			if (channel != null) {
				channel.setVolume(__effectSoundTransform.volume, __effectSoundTransform.pan);
			}
			__effectSoundChannel.push(channel);
			channel.addEventListener(SoundEvent.SOUND_COMPLETE, (e) -> {
				__effectSoundChannel.remove(channel);
			});
			return channel;
		} else {
			return null;
		}
	}

	private var __bgmSoundChannel:ISoundChannel;

	private var __bgmid:String;

	/**
	 * 播放背景音乐，整个生命周期，只会生效一个BGM
	 * @param id 
	 * @return ISoundChannel
	 */
	public function playBGMSound(id:String):ISoundChannel {
		if (__bgmid == id && __bgmSoundChannel != null)
			return __bgmSoundChannel;
		__bgmid = id;
		if (__bgmSoundChannel != null) {
			__bgmSoundChannel.stop();
		}
		var sound = UIManager.getSound(id);
		if (sound != null) {
			__bgmSoundChannel = sound.root.play(true);
			if (__bgmSoundChannel != null) {
				__bgmSoundChannel.setVolume(__musicSoundTransform.volume, __musicSoundTransform.pan);
			}
		}
		return __bgmSoundChannel;
	}

	/**
	 * 停止背景音乐
	 */
	public function stopBGMSound(canResume:Bool = true):Void {
		if (__bgmSoundChannel != null) {
			__bgmSoundChannel.stop();
		}
		__bgmSoundChannel = null;
		if (!canResume)
			__bgmid = null;
	}

	public function stopAllSound():Void {
		stopBGMSound();
		stopAllEffectSound();
	}

	public function stopAllEffectSound():Void {
		for (channel in __effectSoundChannel) {
			channel.stop();
		}
		__effectSoundChannel = [];
	}

	public function resumeBGMSound():Void {
		if (__bgmid != null) {
			this.playBGMSound(__bgmid);
		}
	}

	private var __effectSoundTransform:SoundTransform = new SoundTransform();

	private var __musicSoundTransform:SoundTransform = new SoundTransform();

	/**
	 * 设置音效音量
	 * @param transform 
	 */
	public function setEffectSoundTransform(transform:SoundTransform):Void {
		__effectSoundTransform = transform;
		for (channel in __effectSoundChannel) {
			if (channel != null)
				channel.setVolume(__effectSoundTransform.volume, __effectSoundTransform.pan);
		}
		setMusicSoundTransform(__musicSoundTransform);
	}

	/**
	 * 设置背景音乐音量
	 * @param transform 
	 */
	public function setMusicSoundTransform(transform:SoundTransform):Void {
		__musicSoundTransform = transform;
		if (__bgmSoundChannel != null) {
			__bgmSoundChannel.setVolume(__musicSoundTransform.volume, __musicSoundTransform.pan);
		}
	}
}
