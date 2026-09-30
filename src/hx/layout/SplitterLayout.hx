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
 * 拖动分割条时，位移只发生在该分割条前面板与它和下一条分割条之间的区域，
 * 其它分割条的位置保持不变，与VSCode的拖拽分栏行为一致；
 * 拖拽会把弹性/百分比面板换算为百分比尺寸（声明固定尺寸的面板保持像素模式），
 * 因此窗口缩放时已拖拽调整过的面板会按比例缩放，始终铺满容器
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
	 * 拖动分割条时由`Splitter`回调，将位移量转移为面板的尺寸变化
	 * 遵循VSCode的拖拽逻辑：前面板吸收`delta`，拖动分割条与下一条分割条（或容器末尾）之间的区域吸收`-delta`，
	 * 区域内优先由弹性面板吸收，没有弹性面板时由区域内最后一个面板吸收，因此其它分割条的位置保持不变；
	 * 拖拽后弹性/百分比面板以百分比尺寸记存，窗口缩放时按比例缩放
	 * @param splitter 分割条
	 * @param delta 沿拖动轴的位移量
	 * @return 实际生效的位移量，受0尺寸钳制影响可能小于`delta`
	 */
	public function adjustSplitter(splitter:DisplayObject, delta:Float):Float {
		if (this.parent == null || !(this.parent is DisplayObjectContainer) || delta == 0) {
			return 0;
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
		// 前面板不存在时无法调整
		if (index < 1 || children[index - 1] is Splitter) {
			return 0;
		}
		var prev = children[index - 1];
		// 查找拖动分割条与下一个分割条（或容器末尾）之间的区域
		var endIndex = children.length;
		for (i in index + 1...children.length) {
			if (children[i] is Splitter) {
				endIndex = i;
				break;
			}
		}
		// 区域内优先由弹性面板吸收位移，没有弹性面板时由区域内最后一个面板吸收
		var absorber:DisplayObject = null;
		for (i in index + 1...endIndex) {
			if (this.__isFlex(children[i])) {
				absorber = children[i];
				break;
			}
		}
		if (absorber == null && endIndex - 1 > index) {
			absorber = children[endIndex - 1];
		}
		if (absorber == null) {
			// 区域内没有可吸收位移的面板，放弃本次调整
			return 0;
		}
		var horizontal = this.direction == Direction.HORIZONTAL;
		// 计算排列轴的可用空间（与update保持一致），供百分比尺寸换算使用
		var total = horizontal ? container.width : container.height;
		var splitterTotal = 0.;
		for (child in children) {
			if (child is Splitter) {
				splitterTotal += horizontal ? child.width : child.height;
			}
		}
		var available = total - splitterTotal - this.gap * (children.length - 1);
		var prevBase = horizontal ? prev.width : prev.height;
		var absorberBase = horizontal ? absorber.width : absorber.height;
		// 前面板增长，吸收面板缩小，任一侧到达0时把剩余位移交还对方，保证区域总量不变
		var prevSize = prevBase + delta;
		var absorberSize = absorberBase - delta;
		if (prevSize < 0) {
			absorberSize += prevSize;
			prevSize = 0;
		}
		if (absorberSize < 0) {
			prevSize += absorberSize;
			absorberSize = 0;
		}
		this.applyPanelSize(prev, prevSize, available);
		this.applyPanelSize(absorber, absorberSize, available);
		container.updateLayout();
		return prevSize - prevBase;
	}

	/**
	 * 将面板尺寸写回布局数据
	 * 声明了固定尺寸（`size`）的面板保持像素模式，其余面板（弹性/百分比）写为百分比尺寸，
	 * 这样被拖拽调整过的面板在窗口缩放时会按比例缩放，而声明固定尺寸的面板保持像素不变
	 * @param child 面板
	 * @param size 目标尺寸（沿排列轴的像素值）
	 * @param available 排列轴当前的可用空间
	 */
	private function applyPanelSize(child:DisplayObject, size:Float, available:Float):Void {
		var data = this.getLayoutData(child);
		if (data.size != null && data.percentSize == null) {
			data.size = size;
			return;
		}
		data.size = null;
		data.percentSize = available <= 0 ? 0 : size / available * 100;
	}

	/**
	 * 判断面板是否为弹性面板（未声明`size`与`percentSize`）
	 */
	private function __isFlex(child:DisplayObject):Bool {
		if (child.layoutData != null && child.layoutData is SplitterLayoutData) {
			var data:SplitterLayoutData = cast child.layoutData;
			return data.size == null && data.percentSize == null;
		}
		return true;
	}

	/**
	 * 获得面板的分割布局数据，不存在时创建
	 */
	private function getLayoutData(child:DisplayObject):SplitterLayoutData {
		if (child.layoutData != null && child.layoutData is SplitterLayoutData) {
			return cast child.layoutData;
		}
		var data = new SplitterLayoutData();
		child.layoutData = data;
		return data;
	}
}
