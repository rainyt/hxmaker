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
	 * 数据
	 */
	public var data:Dynamic;

	public var type:String;

	public var cannel:Bool;

	public var bubbling:Bool;

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
