package hx.displays;

import hx.events.Event;

class EventDispatcher {
	/**
	 * 所有侦听器列表
	 */
	@:noCompletion private var __listeners:Map<String, Array<Event->Void>> = [];

	/**
	 * 侦听事件
	 * @param type 
	 * @param listener 
	 */
	public function addEventListener<T>(type:String, listener:T->Void) {
		if (!__listeners.exists(type)) {
			__listeners.set(type, []);
		}
		__listeners.get(type).push(cast listener);
	}

	/**
	 * 删除侦听事件
	 * @param type 
	 * @param listener 
	 */
	public function removeEventListener<T>(type:String, listener:T->Void) {
		if (__listeners.exists(type)) {
			var listeners = __listeners.get(type);
			listeners.remove(cast listener);
		}
	}

	/**
	 * 调用事件
	 * @param event 
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
	 * 是否存在该事件
	 * @param type 
	 * @return Bool
	 */
	public function hasEventListener(type:String):Bool {
		return __listeners.exists(type) && __listeners.get(type).length > 0;
	}
}
