package hx.layout;

import hx.display.Direction;
import hx.display.DisplayObject;
import hx.display.DisplayObjectContainer;
import hx.display.Splitter;

/**
 * 分割布局
 * 面板与`Splitter`分割条混排的布局，面板尺寸由布局统一分配，因此任意容器尺寸下都能自动铺满：
 * - 声明了`SplitterLayoutData.size`的面板使用固定尺寸
 * - 声明了`SplitterLayoutData.percentSize`的面板按百分比分配尺寸
 * - 未声明的面板作为弹性面板，均分剩余空间
 * 拖动分割条时，布局会改写其前面板的固定尺寸（前面板不存在时改写后面板），
 * 弹性面板随即自动吸收剩余空间，以此实现类似VSCode的拖拽分栏效果
 */
class SplitterLayout extends Layout {
	/**
	 * 面板排列方向
	 * `HORIZONTAL`为水平排列（竖直分割条，左右拖拽调整），`VERTICAL`为纵向排列（水平分割条，上下拖拽调整）
	 */
	public var direction:Direction = Direction.HORIZONTAL;

	/**
	 * 间距
	 */
	public var gap:Float = 0;

	/**
	 * 交叉轴是否自动铺满父容器，默认为`true`
	 */
	public var crossFill:Bool = true;

	/**
	 * @param direction 面板排列方向
	 */
	public function new(?direction:Direction) {
		super();
		if (direction != null) {
			this.direction = direction;
		}
	}

	override function update(children:Array<DisplayObject>) {
		super.update(children);
		if (children.length == 0 || this.parent == null) {
			return;
		}
		var parent = this.parent;
		var horizontal = this.direction == Direction.HORIZONTAL;
		// 排列轴总长
		var total = horizontal ? parent.width : parent.height;
		// 分割条总占位
		var splitterTotal = 0.;
		for (child in children) {
			if (child is Splitter) {
				splitterTotal += horizontal ? child.width : child.height;
			}
		}
		// 可分配空间 = 排列轴总长 - 分割条占位 - 间距
		var available = total - splitterTotal - this.gap * (children.length - 1);

		// 第一轮：确定固定与百分比面板的尺寸，记录弹性面板
		var sizes:Array<Float> = [];
		var flexIndices:Array<Int> = [];
		var used = 0.;
		for (i in 0...children.length) {
			var child = children[i];
			if (child is Splitter) {
				sizes.push(horizontal ? child.width : child.height);
				continue;
			}
			if (child.layoutData != null && child.layoutData is SplitterLayoutData) {
				var data:SplitterLayoutData = cast child.layoutData;
				if (data.size != null) {
					var size = data.size < 0 ? 0 : data.size;
					sizes.push(size);
					used += size;
					continue;
				}
				if (data.percentSize != null) {
					var size = available * data.percentSize / 100;
					if (size < 0) {
						size = 0;
					}
					sizes.push(size);
					used += size;
					continue;
				}
			}
			// 未声明尺寸规则的面板作为弹性面板
			sizes.push(0);
			flexIndices.push(i);
		}

		// 第二轮：弹性面板均分剩余空间
		if (flexIndices.length > 0) {
			var flexSize = (available - used) / flexIndices.length;
			if (flexSize < 0) {
				flexSize = 0;
			}
			for (i in flexIndices) {
				sizes[i] = flexSize;
			}
		}

		// 第三轮：沿排列轴依次排布，并把分配到的尺寸写回子项
		var offset = 0.;
		for (i in 0...children.length) {
			var child = children[i];
			if (horizontal) {
				child.x = offset;
				child.width = sizes[i];
				if (this.crossFill) {
					child.y = 0;
					child.height = parent.height;
				}
			} else {
				child.y = offset;
				child.height = sizes[i];
				if (this.crossFill) {
					child.x = 0;
					child.width = parent.width;
				}
			}
			offset += sizes[i] + this.gap;
		}
	}

	/**
	 * 拖动分割条时由`Splitter`回调，将位移量转移为相邻面板的尺寸变化
	 * 默认改写分割条前面板的固定尺寸（前面板不存在时改写后面板，位移取反），
	 * 弹性面板会自动吸收剩余空间
	 * @param splitter 分割条
	 * @param delta 沿拖动轴的位移量
	 */
	public function adjustSplitter(splitter:DisplayObject, delta:Float):Void {
		if (this.parent == null || !(this.parent is DisplayObjectContainer) || delta == 0) {
			return;
		}
		var container:DisplayObjectContainer = cast this.parent;
		// 与update保持一致，仅在可见子项中查找
		var children = container.children.filter((child) -> !child.hide);
		var index = -1;
		for (i in 0...children.length) {
			if (children[i] == splitter) {
				index = i;
				break;
			}
		}
		if (index == -1) {
			return;
		}
		// 默认调整前面板，前面板不存在时调整后面板（位移取反）
		var target:DisplayObject = null;
		var sign = 1.;
		if (index > 0) {
			target = children[index - 1];
		} else if (index < children.length - 1) {
			target = children[index + 1];
			sign = -1;
		}
		if (target == null || target is Splitter) {
			return;
		}
		var data = target.layoutData is SplitterLayoutData ? cast target.layoutData : null;
		if (data == null) {
			data = new SplitterLayoutData();
			target.layoutData = data;
		}
		var current = this.direction == Direction.HORIZONTAL ? target.width : target.height;
		var size = current + delta * sign;
		if (size < 0) {
			size = 0;
		}
		data.size = size;
		container.updateLayout();
	}
}
