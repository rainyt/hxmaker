package hx.events;

/**
 * 事件
 */
class Event {
	/**
	 * 更新事件
	 */
	public inline static var UPDATE:String = "update";

	/**
	 * 尺寸调节事件
	 */
	public inline static var RESIZE:String = "resize";

	public inline static var ADDED_TO_STAGE:String = "addedToStage";

	public inline static var REMOVED_FROM_STAGE:String = "removedFromStage";

	/**
	 * 
	 */
	public inline static var ACTIVATE:String = "activete";

	/**
	 * 
	 */
	public inline static var DEACTIVATE:String = "deactivate";

	/**
	 * 完成统一事件
	 */
	public inline static var COMPLETE:String = "complete";

	/**
	 * 变化
	 */
	public inline static var CHANGE:String = "change";

	/**
	 * 数据
	 */
	public var data:Dynamic;

	public var type:String;

	public var cannel:Bool;

	public var bubbling:Bool;

	public var target:Dynamic;

	/**
	 * 构造一个事件
	 * @param type 事件名
	 * @param cannel 是否可以取消
	 * @param bubbling 是否冒泡
	 */
	public function new(type:String, cannel:Bool = false, bubbling:Bool = false) {
		this.type = type;
		this.cannel = cannel;
		this.bubbling = bubbling;
	}
}
