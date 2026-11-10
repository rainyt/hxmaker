package hx.assets;

interface ISound {
	public function dispose():Void;

	/**
	 * 播放声音。
	 *
	 * [ABN-PATCH 2026-11-10] 新增 `volume` / `pan`（**默认值 = 原行为**，老调用点一行都不用改）。
	 * 为什么需要：openfl 后端每次 `play()` 都会新建一个声道，声道的**初始**增益来自
	 * `SoundMixer.volume × 传入的 SoundTransform.volume`；不传就是 ×1（满音量）。
	 * 而 `SoundManager.playEffectSound()` 是"先 play、再 setVolume 修正"——
	 * 在 html5（howler `<audio>`）上那次修正可能被 howler 排队丢弃（`_playLock`），
	 * 结果整条声音按满音量播完（"偶发一声特别响"）。
	 * ⇒ 让音量**在创建声道时就传给 openfl**，从源头消掉这个窗口。
	 *
	 * @param isLoop 是否循环（各后端语义不同：openfl 后端是"播完再重播"）
	 * @param volume 初始音量（0~1）
	 * @param pan 初始声像（-1~1）
	 */
	public function play(isLoop:Bool = false, volume:Float = 1, pan:Float = 0):ISoundChannel;
}
