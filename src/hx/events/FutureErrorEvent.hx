package hx.events;

/**
 * Future加载错误事件
 */
class FutureErrorEvent extends Event {
	/**
	 * 加载失败
	 */
	public inline static var LOAD_ERROR = "loadError";

	/**
	 * 创建一个FtureErrorEvent对象
	 * @param type 
	 * @param errorCode 
	 * @param error 
	 * @return FutureErrorEvent
	 */
	public static function create(type:String, errorCode:Int, error:String, path:String = null):FutureErrorEvent {
		var e:FutureErrorEvent = new FutureErrorEvent(type);
		e.errorCode = errorCode;
		e.error = error;
		return e;
	}

	/**
	 * 加载路径
	 */
	public var path:String;

	/**
	 * 错误码
	 */
	public var errorCode:Int;

	/**
	 * 错误信息
	 */
	public var error:String;

	public override function toString():String {
		return "FutureErrorEvent[errorCode=" + errorCode + ", error=" + error + ", path=" + path + "]";
	}
}
