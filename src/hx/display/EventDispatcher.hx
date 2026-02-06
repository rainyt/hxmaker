package hx.display;

import hx.events.Event;

/**
 * EventDispatcher类是所有调度事件的类的基类
 * 实现了事件的添加、删除和分发功能
 */
class EventDispatcher implements IEventDispatcher {
	/**
	 * 所有事件侦听器的映射，键为事件类型，值为对应类型的侦听器数组
	 */
	@:noCompletion private var __listeners:Map<String, Array<Event->Void>> = [];

	/**
	 * 添加事件侦听器
	 * @param type 事件类型
	 * @param listener 事件处理函数
	 */
	public function addEventListener<T>(type:String, listener:T->Void) {
		if (!__listeners.exists(type)) {
			__listeners.set(type, []);
		}
		__listeners.get(type).push(cast listener);
	}

	/**
	 * 删除事件侦听器
	 * @param type 事件类型
	 * @param listener 要删除的事件处理函数
	 */
	public function removeEventListener<T>(type:String, listener:T->Void) {
		if (__listeners.exists(type)) {
			var listeners = __listeners.get(type);
			listeners.remove(cast listener);
		}
	}

	/**
	 * 删除所有具有特定类型的事件侦听器，或者如果类型为null，则删除所有事件侦听器
	 * @param type 事件类型，为null时删除所有事件侦听器
	 */
	public function removeEventListeners(type:String = null):Void {
		if (type == null) {
			__listeners = [];
		} else {
			if (__listeners.exists(type)) {
				__listeners.remove(type);
			}
		}
	}

	/**
	 * 分发事件
	 * @param event 要分发的事件对象
	 */
	public function dispatchEvent(event:Event) {
		if (__listeners.exists(event.type)) {
			var listeners = __listeners.get(event.type);
			for (listener in listeners) {
				listener(event);
			}
		}
	}

	/**
	 * 检查是否存在指定类型的事件侦听器
	 * @param type 事件类型
	 * @return 是否存在该类型的事件侦听器
	 */
	public function hasEventListener(type:String):Bool {
		return __listeners.exists(type) && __listeners.get(type).length > 0;
	}
}
