package hx.events;

/** 动画播放器事件；在最终姿态应用后派发，不参与二维事件冒泡。 */
class AnimationEvent3D extends Event {
	public static inline var START:String = "animation3DStart";
	public static inline var LOOP:String = "animation3DLoop";
	public static inline var COMPLETE:String = "animation3DComplete";
	public static inline var FADE_COMPLETE:String = "animation3DFadeComplete";
	public var clipName(default, null):String;
	public var time(default, null):Float;
	/** 本次更新跨越的循环次数；其他事件为零。 */
	public var loopCount(default, null):Float;
	public function new(type:String, clipName:String, time:Float, loopCount:Float = 0) {
		super(type);
		this.clipName = clipName; this.time = time; this.loopCount = loopCount;
	}
}
