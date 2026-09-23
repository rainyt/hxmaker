package hx.layout;

import hx.display.DisplayObject;

/**
 * 虚拟列表布局接口
 *
 * 实现该接口的布局会以固定槽位的方式排列子对象（不累加子对象的实际尺寸），并对外提供可见区域的索引区间与占位对象，
 * 未被渲染的数据区域由占位对象撑起内容尺寸，因此可以承载成千上万条数据。
 *
 * `ListView`通过`layout is IVirtualLayout`识别虚拟列表：把`ListView.layout`设置为虚拟布局（例如`VirtualVerticalLayout`）即可开启虚拟列表。
 */
interface IVirtualLayout extends ILayout {
	/**
	 * 主轴方向上单个槽位占用的尺寸（Item尺寸 + 间距）
	 */
	public var slotSize(get, never):Float;

	/**
	 * 主轴是否为x轴，`true`表示横向布局
	 */
	public var horizontal(get, never):Bool;

	/**
	 * 占位对象，尺寸等于全部数据的内容尺寸
	 * 它自身不会被渲染（空容器不产生DrawCall），也不会响应点击，仅用于支撑滚动范围，由`ListView`负责加入显示列表
	 */
	public var spacer(get, never):DisplayObject;

	/**
	 * 同步需要排列的Item与数据总量，由`ListView`调用
	 * @param items 数据索引与ItemRenderer的映射，包含当前已渲染的全部Item
	 * @param total 数据总量
	 */
	public function setItems(items:Map<Int, DisplayObject>, total:Int):Void;

	/**
	 * 计算可见的数据索引区间
	 * @param data 输出的索引区间，`last`小于`first`时表示没有数据
	 * @param total 数据总量
	 * @param offset 主轴方向上已经滚动的距离
	 * @param viewport 主轴方向上可视区域的尺寸
	 * @param bufferCount 可视区域前后额外渲染的Item数量
	 */
	public function getVisibleRange(data:{first:Int, last:Int}, total:Int, offset:Float, viewport:Float, bufferCount:Int):Void;
}
