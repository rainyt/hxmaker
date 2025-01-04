package hx.display;

import hx.events.Event;

/**
 * MovieClip是一种显示由纹理列表描绘的动画的简单方法。
 */
class MovieClip extends Image {
	@:noCompletion private var __time:Float = 0;
	@:noCompletion private var __playing:Bool = false;

	private var __frames:Array<{
		bitmapData:BitmapData,
		duration:Float,
		sound:Dynamic
	}> = [];

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
	 * @param bitmapDatas 
	 * @param fps 
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
	 * 添加额外的帧，可选地添加声音和自定义持续时间。
	 * @param bitmapData 
	 * @param duration 
	 * @param sound 
	 */
	public function addFrame(bitmapData:BitmapData, duration:Float = 1, sound:Dynamic = null):Void {
		this.__frames.push({
			bitmapData: bitmapData,
			duration: duration,
			sound: sound
		});
	}

	override function onUpdate(dt:Float) {
		if (!__playing)
			return;
		super.onUpdate(dt);
		if (currentFrame >= __frames.length) {
			currentFrame = 0;
		}
		var currentData = __frames[currentFrame];
		if (currentData == null) {
			return;
		}
		__time += dt;
		if (__time >= currentData.duration) {
			currentFrame++;
			__time = 0;
			if (currentFrame >= __frames.length) {
				// 播放完成事件
				if (this.hasEventListener(Event.COMPLETE))
					this.dispatchEvent(new Event(Event.COMPLETE));
			}
		}
	}

	public function play():Void {
		this.__playing = true;
	}

	public function pause():Void {
		this.__playing = false;
	}
}
