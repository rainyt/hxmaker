package hx.events;

import hx.utils.KeyboardTools;

/**
 * 事件
 */
class Event {
	/**
	 * 更新事件
	 */
	public inline static var UPDATE:String = "update";

	/**
	 * 尺寸调节事件
	 */
	public inline static var RESIZE:String = "resize";

	public inline static var ADDED_TO_STAGE:String = "addedToStage";

	public inline static var REMOVED_FROM_STAGE:String = "removedFromStage";

	/**
	 * 删除事件
	 */
	public inline static var REMOVED:String = "removed";

	/**
	 * 添加事件
	 */
	public inline static var ADDED:String = "added";

	/**
	 * 
	 */
	public inline static var ACTIVATE:String = "activete";

	/**
	 * 
	 */
	public inline static var DEACTIVATE:String = "deactivate";

	/**
	 * 完成统一事件
	 */
	public inline static var COMPLETE:String = "complete";

	/**
	 * 变化
	 */
	public inline static var CHANGE:String = "change";

	/**
	 * 成为焦点
	 */
	public inline static var FOCUS_OVER:String = "focusOver";

	/**
	 * 失去焦点
	 */
	public inline static var FOCUS_OUT:String = "focusOut";

	/**
	 * 选择事件
	 */
	public inline static var SELECT:String = "select";

	/**
	 * 数据
	 */
	public var data:Dynamic;

	public var type:String;

	public var cannel:Bool;

	public var bubbling:Bool;

	public var target:Dynamic;

	/**
	 * 构造一个事件
	 * @param type 事件名
	 * @param cannel 是否可以取消
	 * @param bubbling 是否冒泡
	 */
	public function new(type:String, cannel:Bool = false, bubbling:Bool = false, ?data:Dynamic) {
		this.type = type;
		this.cannel = cannel;
		this.bubbling = bubbling;
		this.data = data;
	}

	/**
	 * 是否按下ctrl或command键
	 */
	public var isCtrlOrCommand(get, never):Bool;

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
