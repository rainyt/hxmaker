package hx.assets;

import haxe.Timer;
import hx.events.FutureErrorEvent;

class Future<T, DATA> {
	@:noCompletion private var __completes:Array<T->Void> = [];
	@:noCompletion private var __errors:Array<FutureErrorEvent->Void> = [];
	@:noCompletion private var __dones:Array<Void->Void> = [];
	@:noCompletion private var __data:DATA;

	public var error(default, null):FutureErrorEvent;
	public var isComplete(default, null):Bool;
	public var isError(default, null):Bool;
	public var value(default, null):T;

	public var autoPost:Bool = true;

	public function new(data:DATA, autoPost:Bool = true) {
		__data = data;
		this.autoPost = autoPost;
		Timer.delay(() -> {
			if (this.autoPost)
				post();
		}, 16);
	}

	/**
	 * 发起请求
	 */
	public function post():Void {}

	/**
	 * 获得加载数据
	 * @return Dynamic
	 */
	public function getLoadData():DATA {
		return __data;
	}

	public function onComplete(listener:T->Void):Future<T, DATA> {
		__completes.push(listener);
		return this;
	}

	public function onError(listener:FutureErrorEvent->Void):Future<T, DATA> {
		__errors.push(listener);
		return this;
	}

	public function onDone(listener:Void->Void):Future<T, DATA> {
		__dones.push(listener);
		return this;
	}

	/**
	 * 自定处理成功函数
	 */
	private var __customCompleteValue:Future<T, DATA>->T->Void;

	/**
	 * 自定义处理成功数据，但请注意，需要主动调用`completeValue`或者`errorValue`才能结束当前请求
	 * @param value 
	 */
	public function customCompleteValue(cb:Future<T, DATA>->T->Void):Future<T, DATA> {
		__customCompleteValue = cb;
		return this;
	}

	/**
	 * 当请求成功，则返回值
	 * @param value 
	 */
	public function completeValue(value:T):Void {
		if (__customCompleteValue != null) {
			var redayCb = __customCompleteValue;
			__customCompleteValue = null;
			redayCb(this, value);
			return;
		}
		this.isComplete = true;
		this.value = value;
		for (cb in __completes) {
			cb(this.value);
		}
		for (cb in __dones) {
			cb();
		}
		this.__completes = [];
		this.__errors = [];
		this.__dones = [];
	}

	/**
	 * 当请求失败，则返回错误
	 * @param data 
	 */
	public function errorValue(data:FutureErrorEvent):Void {
		this.isError = true;
		this.error = data;
		for (cb in __errors) {
			cb(this.error);
		}
		for (cb in __dones) {
			cb();
		}
	}

	/**
	 * 获得路径
	 */
	public var path(get, never):String;

	private function get_path():String {
		var data:Dynamic = __data;
		if (data is String) {
			return data;
		}
		return data.path;
	}
}
