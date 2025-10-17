package hx.events;

import spine.animation.TrackEntry;

/**
 * Spine事件
 */
class SpineEvent extends Event {
	/**
	 * Spine事件
	 */
	public static inline var EVENT = "spine_event";

	/**
	 * 开始事件
	 */
	public static inline var START = "spine_start";

	/**
	 * 结束事件
	 */
	public static inline var END = "spine_end";

	/**
	 * 销毁事件
	 */
	public static inline var DISPOSE = "spine_dispose";

	/**
	 * 中断事件
	 */
	public static inline var INTERRUPT = "spine_interrupt";

	/**
	 * Spine原生事件对象
	 */
	public var event:spine.Event;

	/**
	 * Spine动画对象
	 */
	public var trackEntry:TrackEntry;
}
