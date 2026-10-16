package hx.events;

/** 动画播放器事件；在最终姿态应用后派发，不参与二维事件冒泡。 */
class AnimationEvent3D extends Event {
	/** 目标片段开始播放事件。 */
	public static inline var START:String = "animation3DStart";

	/** 当前目标片段跨越循环边界事件，同一次 update 合并次数。 */
	public static inline var LOOP:String = "animation3DLoop";

	/** 非循环目标片段完成事件，每次播放只派发一次。 */
	public static inline var COMPLETE:String = "animation3DComplete";

	/** 当前姿态过渡完成事件。 */
	public static inline var FADE_COMPLETE:String = "animation3DFadeComplete";

	/** 事件所属目标片段名。 */
	public var clipName(default, null):String;

	/** 事件发生时相对目标片段起点的秒数。 */
	public var time(default, null):Float;

	/** 本次更新跨越的循环次数；其他事件为零。 */
	public var loopCount(default, null):Float;

	/** 创建不冒泡的动画事件；循环次数默认为零。 */
	public function new(type:String, clipName:String, time:Float, loopCount:Float = 0) {
		super(type);
		this.clipName = clipName;
		this.time = time;
		this.loopCount = loopCount;
	}
}
