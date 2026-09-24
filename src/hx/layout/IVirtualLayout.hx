package hx.layout;

import hx.display.DisplayObject;

/**
 * 虚拟列表布局接口
 *
 * 实现该接口的布局以固定单元格（槽位）的方式排列子对象，不累加子对象的实际尺寸，并对外提供可见区域的索引区间与占位对象，
 * 未被渲染的数据区域由占位对象撑起内容尺寸，因此可以承载成千上万条数据。
 *
 * `ListView`通过`layout is IVirtualLayout`识别虚拟列表：把`ListView.layout`设置为虚拟布局（例如`VirtualVerticalLayout`）即可开启虚拟列表。
 * 布局只负责几何计算（可见区间、Item位置与尺寸、占位对象），ItemRenderer的创建、回收与数据绑定由`ListView`负责。
 */
interface IVirtualLayout extends ILayout {
	/**
	 * 主轴是否为x轴，`true`表示横向布局
	 */
	public var horizontal(get, never):Bool;

	/**
	 * 全部数据占用的主轴尺寸
	 */
	public var contentSize(get, never):Float;

	/**
	 * 占位对象，尺寸等于全部数据的内容尺寸
	 * 它自身不会被渲染（空容器不产生DrawCall），也不会响应点击，仅用于支撑滚动范围，由`ListView`负责加入显示列表
	 */
	public var spacer(get, never):DisplayObject;

	/**
	 * 获得某个数据索引在主轴方向上的起始位置
	 * 网格（流）布局中同一行的Item位置相同，`ListView.scrollToIndex()`会使用该位置
	 */
	public function getItemOffset(index:Int):Float;

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
	 * @param bufferCount 可视区域前后额外渲染的行数
	 */
	public function getVisibleRange(data:{first:Int, last:Int}, total:Int, offset:Float, viewport:Float, bufferCount:Int):Void;
}
