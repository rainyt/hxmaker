package hx.layout;

import hx.display.Box;
import hx.display.DisplayObject;

/**
 * 虚拟列表的流布局（等宽等高的网格）
 *
 * 与`FlowLayout`的区别：
 * - Item以固定单元格排列（`itemWidth` × `itemHeight`），列数由父容器宽度与`gapX`决定，因此Item的位置只与数据索引有关，不依赖Item自身的尺寸
 * - 数据按行推进，主轴为y轴：`index`所在的行决定了Item的主轴位置
 * - 没有被渲染的数据区域由`spacer`支撑内容尺寸，配合`ListView`即可实现大数据量的网格/流列表
 */
class VirtualFlowLayout extends FlowLayout implements IVirtualLayout {
	/**
	 * 单元格宽度，需要大于`0`
	 */
	public var itemWidth:Float;

	/**
	 * 单元格高度，需要大于`0`
	 */
	public var itemHeight:Float;

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
	 * @param itemWidth 单元格宽度
	 * @param itemHeight 单元格高度
	 * @param gapX 横向间隔
	 * @param gapY 竖向间隔
	 */
	public function new(itemWidth:Float, itemHeight:Float, gapX:Float = 0, gapY:Float = 0) {
		super(gapX, gapY);
		this.itemWidth = itemWidth;
		this.itemHeight = itemHeight;
	}

	/**
	 * 一行占用的主轴尺寸（单元格高度 + 竖向间隔）
	 */
	public var rowHeight(get, never):Float;

	private function get_rowHeight():Float {
		return this.itemHeight + this.gapY;
	}

	/**
	 * 每行的Item数量，由父容器宽度、`itemWidth`与`gapX`决定，至少为`1`
	 */
	public var columns(get, never):Int;

	private function get_columns():Int {
		var width = this.parent != null ? this.parent.width : 0;
		var step = this.itemWidth + this.gapX;
		if (step <= 0) {
			return 1;
		}
		var count = Std.int((width + this.gapX) / step);
		return count > 0 ? count : 1;
	}

	public var contentSize(get, never):Float;

	private function get_contentSize():Float {
		var columns = this.columns;
		var rows = Std.int((this.__total + columns - 1) / columns);
		var size = rows * this.rowHeight - this.gapY;
		return size > 0 ? size : 0;
	}

	public function getItemOffset(index:Int):Float {
		return Std.int(index / this.columns) * this.rowHeight;
	}

	public var horizontal(get, never):Bool;

	private function get_horizontal():Bool {
		return false;
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
		VirtualLayoutUtils.getVisibleRange(data, total, this.columns, this.rowHeight, offset, viewport, bufferCount);
	}

	/**
	 * 按单元格排列Item，不使用`FlowLayout`按子对象实际尺寸换行的方式：虚拟列表的Item数量不等于数据总量，换行点必须由数据索引计算
	 */
	override function update(children:Array<DisplayObject>) {
		if (this.__items == null || this.parent == null) {
			return;
		}
		var columns = this.columns;
		var stepX = this.itemWidth + this.gapX;
		var rowHeight = this.rowHeight;
		for (index => item in this.__items) {
			var row = Std.int(index / columns);
			item.x = (index % columns) * stepX;
			item.y = row * rowHeight;
		}
		this.__updateSpacer();
	}

	/**
	 * 更新占位对象的尺寸，使其等于全部数据的内容高度
	 */
	private function __updateSpacer():Void {
		if (this.__spacer == null) {
			return;
		}
		this.__spacer.x = 0;
		this.__spacer.y = 0;
		this.__spacer.width = this.parent != null ? this.parent.width : 0;
		this.__spacer.height = this.contentSize;
	}
}
