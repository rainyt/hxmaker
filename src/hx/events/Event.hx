package hx.events;

import hx.utils.KeyboardTools;
import hx.events.Keyboard;

/**
 * 事件类，所有事件的基类
 * 定义了事件系统的核心属性和方法
 */
@:keep
class Event {
	/**
	 * 更新事件，每帧触发
	 */
	public inline static var UPDATE:String = "update";

	/**
	 * 尺寸调节事件，当对象尺寸发生变化时触发
	 */
	public inline static var RESIZE:String = "resize";

	/**
	 * 添加到舞台事件，当对象被添加到舞台时触发
	 */
	public inline static var ADDED_TO_STAGE:String = "addedToStage";

	/**
	 * 从舞台移除事件，当对象从舞台移除时触发
	 */
	public inline static var REMOVED_FROM_STAGE:String = "removedFromStage";

	/**
	 * 删除事件，当对象被删除时触发
	 */
	public inline static var REMOVED:String = "removed";

	/**
	 * 添加事件，当对象被添加时触发
	 */
	public inline static var ADDED:String = "added";

	/**
	 * 激活事件，当程序获得焦点时触发
	 */
	public inline static var ACTIVATE:String = "activate";

	/**
	 * 停用事件，当程序失去焦点时触发
	 */
	public inline static var DEACTIVATE:String = "deactivate";

	/**
	 * 完成事件，当操作完成时触发
	 */
	public inline static var COMPLETE:String = "complete";

	/**
	 * 变化事件，当对象状态发生变化时触发
	 */
	public inline static var CHANGE:String = "change";

	/**
	 * 获得焦点事件，当对象获得焦点时触发
	 */
	public inline static var FOCUS_OVER:String = "focusOver";

	/**
	 * 失去焦点事件，当对象失去焦点时触发
	 */
	public inline static var FOCUS_OUT:String = "focusOut";

	/**
	 * 选择事件，当对象被选择时触发
	 */
	public inline static var SELECT:String = "select";

	/**
	 * 事件相关的数据
	 */
	public var data:Dynamic;

	/**
	 * 事件类型
	 */
	public var type:String;

	/**
	 * 是否可以取消事件
	 */
	public var cannel:Bool;

	/**
	 * 是否冒泡
	 */
	public var bubbling:Bool;

	/**
	 * 事件目标对象
	 */
	public var target:Dynamic;

	/**
	 * 构造一个事件
	 * @param type 事件类型
	 * @param cannel 是否可以取消
	 * @param bubbling 是否冒泡
	 * @param data 事件相关的数据
	 */
	public function new(type:String, cannel:Bool = false, bubbling:Bool = false, ?data:Dynamic) {
		this.type = type;
		this.cannel = cannel;
		this.bubbling = bubbling;
		this.data = data;
	}

	/**
	 * 是否按下ctrl或command键
	 * @return 是否按下了ctrl或command键
	 */
	public var isCtrlOrCommand(get, never):Bool;

	/**
	 * 获取是否按下了ctrl或command键
	 * @return 是否按下了ctrl或command键
	 */
	private function get_isCtrlOrCommand():Bool {
		return KeyboardTools.isKeyDown(Keyboard.CONTROL) || KeyboardTools.isKeyDown(Keyboard.COMMAND);
	}

	/**
	 * 阻止默认行为
	 */
	public function preventDefault():Void {
		this.cannel = true;
	}
}
