package hx.display;

import hx.events.Event;

interface IEventDispatcher {
	public function addEventListener<T>(type:String, listener:T->Void):Void;
	public function removeEventListener<T>(type:String, listener:T->Void):Void;
	public function removeEventListeners(type:String = null):Void;
	public function dispatchEvent(event:Event):Void;
	public function hasEventListener(type:String):Bool;
}
