package hx.display;

import hx.assets.Sound;
import hx.events.Event;

/**
 * MovieClip是一种显示由纹理列表描绘的动画的简单方法。
 */
@:keep
class MovieClip extends Image {
	@:noCompletion private var __time:Float = 0;
	@:noCompletion private var __playing:Bool = false;

	/**
	 * 重置播放时间和帧，会回到`0`帧
	 */
	public function reset():Void {
		__time = 0;
		currentFrame = 0;
	}

	/**
	 * 是否启用声音
	 * 默认值为true
	 */
	public var enableSound:Bool = true;

	private var __frames:Array<{
		bitmapData:BitmapData,
		duration:Float,
		sound:Sound
	}> = [];

	/**
	 * 清空所有帧数据
	 */
	public function cleanFrames():Void {
		__frames = [];
	}

	/**
	 * 获取总帧数
	 */
	public var totalFrame(get, never):Int;

	private function get_totalFrame():Int {
		return __frames.length;
	}

	/**
	 * 获取当前是否正在播放动画
	 */
	public var playing(get, never):Bool;

	private function get_playing():Bool {
		return __playing;
	}

	/**
	 * 获得当前选择的帧
	 */
	public var currentFrame(default, set):Int = 0;

	private function set_currentFrame(value:Int):Int {
		this.currentFrame = value;
		var currentData = __frames[currentFrame];
		if (currentData == null) {
			return value;
		}
		this.data = currentData.bitmapData;
		return value;
	}

	/**
	 * 根据提供的纹理和指定的默认帧速率创建电影剪辑。
	 * @param bitmapDatas 每帧渲染的位图数据数组
	 * @param fps 每帧间隔的帧率，将会自动转换为`duration`值
	 */
	public function new(bitmapDatas:Array<BitmapData> = null, fps:Float = 12) {
		super();
		if (bitmapDatas != null) {
			for (data in bitmapDatas) {
				addFrame(data, 1 / fps);
			}
		}
		this.updateEnabled = true;
	}

	/**
	 * 设置动画列表
	 * @param bitmapDatas 每帧渲染的位图数据数组
	 * @param fps 每帧间隔的帧率，将会自动转换为`duration`值
	 */
	public function setBitmapDatas(bitmapDatas:Array<BitmapData>, fps:Float = 12):Void {
		this.__frames = [];
		if (bitmapDatas != null)
			for (data in bitmapDatas) {
				addFrame(data, 1 / fps);
			}
	}

	/**
	 * 添加额外的帧，可选地添加声音和自定义持续时间。
	 * @param bitmapData 渲染的位图数据
	 * @param duration 该帧显示的持续时间
	 * @param sound 播放音频
	 */
	public function addFrame(bitmapData:BitmapData, duration:Float = 1, sound:Sound = null):Void {
		this.__frames.push({
			bitmapData: bitmapData,
			duration: duration,
			sound: sound
		});
		if (data == null) {
			this.currentFrame = 0;
		}
	}

	private var __currentFrame:Int = -1;

	/**
	 * 获得当前帧到下一帧的持续时间，单位为秒
	 */
	public var duration(get, never):Float;

	private function get_duration():Float {
		var duration = 0;
		var currentData = __frames[currentFrame];
		if (currentData == null) {
			return duration;
		}
		return currentData.duration;
	}

	override function onUpdate(dt:Float) {
		if (!__playing)
			return;
		super.onUpdate(dt);
		if (currentFrame >= __frames.length) {
			currentFrame = 0;
			__time = 0;
		}
		var currentData = __frames[currentFrame];
		if (currentData == null) {
			return;
		}
		if (__time >= currentData.duration) {
			currentFrame++;
			__time -= currentData.duration;
			if (currentFrame >= __frames.length) {
				// 播放完成事件
				if (this.hasEventListener(Event.COMPLETE))
					this.dispatchEvent(new Event(Event.COMPLETE));
			}
			// 帧发生变化时处理
			if (this.hasEventListener(Event.CHANGE))
				this.dispatchEvent(new Event(Event.CHANGE));
			// 音效播放支持
			currentData = __frames[currentFrame];
			if (enableSound && currentData != null && currentData.sound != null) {
				currentData.sound.root.play();
			}
		}
		__time += dt;
	}

	/**
	 * 播放动画
	 */
	public function play():Void {
		this.__playing = true;
	}

	/**
	 * 暂停动画
	 */
	public function pause():Void {
		this.__playing = false;
	}

	/**
	 * 停止到某一帧
	 * @param frame 设置帧，由0开始计算
	 */
	public function stopAt(frame:Int):Void {
		currentFrame = frame;
		this.pause();
	}
}
