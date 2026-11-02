package hx.events;

import hx.spine.SpineTypes.TrackEntry;
import hx.spine.SpineTypes.NativeEvent;

/**
 * Spine事件
 */
@:build(hx.macro.SpineMacro.build())
class SpineEvent extends Event {
	/**
	 * Spine事件
	 */
	public static inline var EVENT:String = "spine_event";

	/**
	 * 开始事件
	 */
	public static inline var START:String = "spine_start";

	/**
	 * 结束事件
	 */
	public static inline var END:String = "spine_end";

	/**
	 * 销毁事件
	 */
	public static inline var DISPOSE:String = "spine_dispose";

	/**
	 * 中断事件
	 */
	public static inline var INTERRUPT:String = "spine_interrupt";

	/**
	 * Spine原生事件对象
	 */
	public var event:NativeEvent;

	/**
	 * Spine动画对象
	 */
	public var trackEntry:TrackEntry;

	/**
	 * 转换为字符串表示
	 * @return Spine事件的字符串描述
	 */
	public override function toString():String {
		return "SpineEvent[type=" + type + "]";
	}
}
