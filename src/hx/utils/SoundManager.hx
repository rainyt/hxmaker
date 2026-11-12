package hx.utils;

import hx.assets.Assets;
import hx.assets.Sound;
import hx.events.SoundEvent;
import haxe.Timer;
import hx.ui.UIManager;
import hx.assets.ISoundChannel;
import hx.media.SoundTransform;

using haxe.io.Path;

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
	 * 播放音效（异步）
	 * @param path 音效路径
	 * @param isLoop 是否循环播放
	 */
	public function playEffectFromPath(path:String, isLoop:Bool = false):Void {
		var id = path.withoutExtension().withoutDirectory();
		if (UIManager.getSound(id) != null) {
			playEffect(id, isLoop);
		} else {
			// 异步加载
			var assets = new Assets();
			assets.loadSound(path, false);
			assets.onComplete((a) -> {
				#if sound_debug
				trace("[SoundManager] playEffectFromPath: " + id);
				#end
				playEffectSound(a.data.getSound(id), isLoop);
			});
			assets.start();
		}
	}

	/**
	 * 播放音效
	 * @param id 
	 * @param isLoop 是否循环播放
	 * @param isForce 是否强制播放
	 * @return ISoundChannel，该对象在不可播放的情况下会返回`null`
	 */
	public function playEffect(id:String, isLoop:Bool = false, isForce:Bool = false):ISoundChannel {
		if (!__effectEnable)
			return null;
		var now = Timer.stamp();
		if (!isForce && __soundEffects.exists(id)) {
			if (now - __soundEffects.get(id) < effectTimeInterval) {
				#if sound_debug
				trace("[SoundManager] ignore playEffect: " + id);
				#end
				return null;
			}
		}
		#if sound_debug
		trace("[SoundManager] playEffect: " + id);
		#end
		__soundEffects.set(id, now);
		var sound = UIManager.getSound(id);
		return this.playEffectSound(sound, isLoop);
	}

	/**
	 * 播放音效
	 * @param sound 
	 * @return ISoundChannel，该对象在不可播放的情况下会返回`null`
	 */
	public function playEffectSound(sound:Sound, isLoop:Bool = false):ISoundChannel {
		if (!__effectEnable)
			return null;
		if (sound != null) {
			// [ABN-PATCH 2026-11-12] 起播前先把当前音量写到后端（`OpenFLSound.volume/pan`），
			// 让它随 `Sound.play(startTime, loops, sndTransform)` 一起进声道。
			// 为什么不能只靠下面那句 setVolume：html5 后端（howler `<audio>`）在 `_playLock` 时
			// 会把 `Howl.volume()` 塞进队列，而 howler 的 `_loadQueue` 只认 "play" ⇒ 该记录**永不执行**
			// ⇒ 该次播放整条按满音量（玩家实测：命中音效不受音量控制）。
			// `ISound` 接口不动（作者口径）：反射写字段，没有该字段的后端无害。
			setRootPlayVolume(sound, __effectSoundTransform.volume, __effectSoundTransform.pan);
			var channel = sound.root.play(isLoop);
			if (channel != null) {
				// 保留：① 让"正在播的声道"跟随之后的音量变化；② 兼容不认起播音量的后端
				channel.setVolume(__effectSoundTransform.volume, __effectSoundTransform.pan);
				__effectSoundChannel.push(channel);
				channel.addEventListener(SoundEvent.SOUND_COMPLETE, (e) -> {
					__effectSoundChannel.remove(channel);
				});
			}
			return channel;
		} else {
			return null;
		}
	}

	/**
	 * [ABN-PATCH 2026-11-12] 把"起播音量"写到 `ISound` 实现上（目前只有 `OpenFLSound` 有这个字段）。
	 *
	 * 用反射而不是接口参数：`ISound.play(isLoop, volume, pan)` 那种改法对其它后端是破坏性变更
	 * （引擎作者明确反对）；这里对没有该字段的实现是无害空操作。
	 * 失败静默：任何后端都不该因为"设不了起播音量"而让一次播放失败。
	 */
	private static function setRootPlayVolume(sound:Sound, volume:Float, pan:Float):Void {
		try {
			Reflect.setField(sound.root, "volume", volume);
			Reflect.setField(sound.root, "pan", pan);
		} catch (e:Dynamic) {}
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
		if (!__musicEnable) {
			return null;
		}
		if (__bgmSoundChannel != null) {
			__bgmSoundChannel.stop();
		}
		var sound = UIManager.getSound(id);
		if (sound != null) {
			// [ABN-PATCH 2026-11-12] 同 playEffectSound：BGM 也把音量写在起播前（理由见那里）
			setRootPlayVolume(sound, __musicSoundTransform.volume, __musicSoundTransform.pan);
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
	 * 更新音量
	 */
	public function updateVolume():Void {
		setEffectSoundTransform(__effectSoundTransform);
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

	private var __effectEnable:Bool = true;

	/**
	 * 设置音效开关
	 * @param enable 
	 */
	public function setEffectEnable(enable:Bool):Void {
		__effectEnable = enable;
		if (!__effectEnable)
			this.stopAllEffectSound();
	}

	private var __musicEnable:Bool = true;

	/**
	 * 设置背景音乐开关
	 * @param enable 
	 */
	public function setMusicEnable(enable:Bool):Void {
		__musicEnable = enable;
		if (!__musicEnable)
			this.stopBGMSound();
		else {
			this.resumeBGMSound();
		}
	}
}
