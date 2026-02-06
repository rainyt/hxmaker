package hx.display;

import hx.events.Event;

/**
 * 数组集合类，提供了对数组的封装和事件通知机制
 * 当数组元素发生变化时，会自动分发相应的事件
 */
class ArrayCollection extends EventDispatcher {
	/**
	 * 内部存储的数组数据源
	 */
	public var source:Array<Dynamic>;

	/**
	 * 构造一个数组集合
	 * @param array 初始数组数据
	 */
	public function new(array:Array<Dynamic>) {
		this.source = array;
	}

	/**
	 * 删除指定元素
	 * @param item 要删除的元素
	 * @return 是否成功删除元素
	 */
	public function remove(item:Dynamic):Bool {
		var index = source.indexOf(item);
		if (index < 0)
			return false;
		source.splice(index, 1);
		this.dispatchEvent(new Event(Event.REMOVED, item));
		return true;
	}

	/**
	 * 添加元素
	 * @param item 要添加的元素
	 * @return 是否成功添加元素（如果元素已存在则返回false）
	 */
	public function add(item:Dynamic):Bool {
		if (source.indexOf(item) >= 0)
			return false;
		source.push(item);
		this.dispatchEvent(new Event(Event.ADDED, item));
		return true;
	}

	/**
	 * 根据索引获取元素
	 * @param index 元素的索引
	 * @return 指定索引的元素
	 */
	public function get(index:Int):Dynamic {
		return source[index];
	}

	/**
	 * 清空所有元素
	 * 会为每个被删除的元素分发REMOVED事件
	 */
	public function clear():Void {
		var items = source.copy();
		for (value in items) {
			this.remove(value);
		}
	}

	/**
	 * 获取数组集合的长度
	 * @return 数组集合的元素数量
	 */
	public var length(get, null):Int;

	/**
	 * 获取数组长度的内部实现
	 * @return 数组的长度
	 */
	private function get_length():Int {
		return source.length;
	}
}
