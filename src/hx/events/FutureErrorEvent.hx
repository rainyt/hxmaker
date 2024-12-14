package hx.events;

/**
 * Future加载错误事件
 */
class FutureErrorEvent extends Event {
	/**
	 * 创建一个FtureErrorEvent对象
	 * @param type 
	 * @param errorCode 
	 * @param error 
	 * @return FutureErrorEvent
	 */
	public static function create(type:String, errorCode:Int, error:String):FutureErrorEvent {
		var e:FutureErrorEvent = new FutureErrorEvent(type);
		e.errorCode = errorCode;
		e.error = error;
		return e;
	}

	/**
	 * 错误码
	 */
	public var errorCode:Int;

	/**
	 * 错误信息
	 */
	public var error:String;
}
