package hx.events;

/**
 * 未捕获错误事件
 * 用于处理底层引擎中的未捕获错误
 */
class UncaughtErrorEvent extends Event {
	/**
	 * 未捕获错误事件类型
	 */
	public inline static var UNCAUGHT_ERROR = "uncaughtError";

	/**
	 * 构造一个UncaughtErrorEvent对象
	 * @param type 事件类型
	 * @param error 错误对象
	 * @param message 错误消息
	 * @param stack 错误堆栈信息
	 * @param cannel 是否可以取消
	 * @param bubbling 是否冒泡
	 */
	public function new(type:String, error:Dynamic, message:String, stack:String, cannel:Bool = false, bubbling:Bool = false) {
		super(type, cannel, bubbling);
		this.error = error;
		this.message = message;
		this.stack = stack;
	}

	/**
	 * 错误对象
	 */
	public var error:Dynamic;

	/**
	 * 错误消息
	 */
	public var message:String;

	/**
	 * 错误堆栈信息
	 */
	public var stack:String;

	/**
	 * 转换为字符串表示
	 * @return 错误事件的字符串描述
	 */
	public override function toString():String {
		return "UncaughtErrorEvent[message=" + message + ", stack=" + stack + "]";
	}
}
