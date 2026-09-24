package hx.layout;

import hx.display.Box;
import hx.display.DisplayObject;

/**
 * 虚拟列表的横向布局
 *
 * 与`HorizontalLayout`的区别：
 * - 子对象按固定槽位排列（`itemSize` + `gap`），不会累加子对象的实际宽度，因此滚动过程中回收复用Item也不会造成布局抖动
 * - 没有被渲染的数据区域由`spacer`支撑内容尺寸，配合`ListView`即可实现大数据量的虚拟列表
 * - `spacer`由布局持有，与Item一样以数据索引定位，因此只排列数据索引与Item的映射，其余子对象不参与排列
 */
class VirtualHorizontalLayout extends HorizontalLayout implements IVirtualLayout {
	/**
	 * 单个Item的宽度，需要大于`0`
	 */
	public var itemSize(default, set):Float;

	private function set_itemSize(value:Float):Float {
		if (this.itemSize != value) {
			this.itemSize = value;
			this.__updateSpacer();
		}
		return value;
	}

	/**
	 * 数据索引与Item的映射
	 */
	private var __items:Map<Int, DisplayObject> = null;

	/**
	 * 数据总量
	 */
	private var __total:Int = 0;

	/**
	 * 占位对象
	 */
	private var __spacer:Box = null;

	/**
	 * @param itemSize 单个Item的宽度
	 */
	public function new(itemSize:Float) {
		super();
		this.itemSize = itemSize;
	}

	/**
	 * 主轴方向一个槽位占用的尺寸（Item宽度 + 间距）
	 */
	public var slotSize(get, never):Float;

	private function get_slotSize():Float {
		return this.itemSize + this.gap;
	}

	public var contentSize(get, never):Float;

	private function get_contentSize():Float {
		var size = this.__total * this.slotSize - this.gap;
		return size > 0 ? size : 0;
	}

	public function getItemOffset(index:Int):Float {
		return index * this.slotSize;
	}

	public var horizontal(get, never):Bool;

	private function get_horizontal():Bool {
		return true;
	}

	public var spacer(get, never):DisplayObject;

	private function get_spacer():DisplayObject {
		if (this.__spacer == null) {
			// 空容器不产生任何绘制开销，也不参与点击，仅用于支撑滚动范围
			this.__spacer = new Box();
			this.__spacer.mouseEnabled = false;
		}
		return this.__spacer;
	}

	public function setItems(items:Map<Int, DisplayObject>, total:Int):Void {
		this.__items = items;
		this.__total = total;
	}

	public function getVisibleRange(data:{first:Int, last:Int}, total:Int, offset:Float, viewport:Float, bufferCount:Int):Void {
		// 横向列表每列只有一个Item
		VirtualLayoutUtils.getVisibleRange(data, total, 1, this.slotSize, offset, viewport, bufferCount);
	}

	/**
	 * 排列Item，不使用`HorizontalLayout`累加子对象宽度的方式：虚拟列表的Item以数据索引定位，未被渲染的数据区域没有子对象
	 */
	override function update(children:Array<DisplayObject>) {
		if (this.__items == null || this.parent == null) {
			return;
		}
		var slot = this.slotSize;
		var height = this.parent.height;
		for (index => item in this.__items) {
			item.x = index * slot;
			if (this.verticalFill) {
				item.height = height;
			}
			// 与HorizontalLayout保持一致的对齐方式
			switch (this.verticalAlign) {
				case MIDDLE:
					item.y = (height - item.height) / 2;
				case BOTTOM:
					item.y = height - item.height;
				case TOP, null:
					item.y = 0;
			}
		}
		this.__updateSpacer();
	}

	/**
	 * 更新占位对象的尺寸，使其等于全部数据的内容宽度
	 */
	private function __updateSpacer():Void {
		if (this.__spacer == null) {
			return;
		}
		this.__spacer.x = 0;
		this.__spacer.y = 0;
		this.__spacer.width = this.contentSize;
		this.__spacer.height = this.parent != null ? this.parent.height : 0;
	}
}
