package hx.display;

/**
 * 显示对象实现此接口后可参与 Tab 焦点切换。
 * 只有当前焦点也实现此接口且允许切换时，舞台才查询候选对象。
 */
interface ITabFocusable {
	/** 是否参与 Tab 切换；关闭后也不能作为切换起点。 */
	public var tabEnabled:Bool;

	/** 按数值从小到大排序，相同时按显示树顺序；负数表示不参与。 */
	public var tabIndex:Int;

	/** 舞台设置焦点后调用，在此接入键盘输入或更新焦点样式。 */
	public function focus():Void;
}
