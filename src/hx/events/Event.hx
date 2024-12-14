package hx.events;

/**
 * 事件
 */
class Event {
	/**
	 * 数据
	 */
	public var data:Dynamic;

	/**
	 * 构造一个事件
	 * @param type 事件名
	 * @param cannel 是否可以取消
	 * @param bubbling 是否冒泡
	 */
	public function new(type:String, cannel:Bool = false, bubbling:Bool = false) {}
}
