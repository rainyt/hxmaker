package hx.display;

/**
 * MovieClip是一种显示由纹理列表描绘的动画的简单方法。
 */
class MovieClip extends Image {
	@:noCompletion private var __time:Float = 0;

	private var __frames:Array<{
		bitmapData:BitmapData,
		duration:Float,
		sound:Dynamic
	}> = [];

	/**
	 * 获得当前选择的帧
	 */
	public var currentFrame:Int = 0;

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

	public function addFrame(bitmapData:BitmapData, duration:Float = 1, sound:Dynamic = null):Void {
		this.__frames.push({
			bitmapData: bitmapData,
			duration: duration,
			sound: sound
		});
	}

	override function onUpdate(dt:Float) {
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
		}
		this.data = currentData.bitmapData;
	}
}
