package hx.display;

/**
 * 默认的Tree行渲染器，提供选中/悬停背景、展开箭头（twisty）与文本展示
 *
 * 自定义渲染器继承`TreeItemRenderer`后，缩进、展开箭头与选中/悬停背景会自动维护，
 * 只需要在`setData`中处理自定义内容；`data`为`TreeRowData`结构（`item`为节点，`depth`为层级深度）。
 */
@:keep
class TreeItemRenderer extends ItemRenderer {
	/**
	 * 所属的树，由`Tree`在创建渲染器时设置，样式参数从中读取
	 */
	public var tree:Tree = null;

	/**
	 * 节点文本
	 */
	public var label:Label = new Label();

	/**
	 * 展开箭头，文件夹节点可见
	 */
	public var twisty:Graphics = new Graphics();

	/**
	 * 行背景，选中与悬停时可见
	 *
	 * 它同时作为整行的点击热区：未高亮时保持显示但`alpha = 0`（渲染时会跳过`alpha == 0`的对象，不产生绘制开销），
	 * 高亮时`alpha = 1`。请勿将它设置为不可见或关闭鼠标事件，否则点击行的空白区域将无法命中
	 */
	public var backgroundQuad:Quad = new Quad(0, 0, 0xffffff);

	private var __hovered:Bool = false;

	/**
	 * 是否处于悬停状态，由`Tree`维护
	 */
	public var hovered(get, set):Bool;

	/**
	 * 最近一次绘制箭头使用的颜色，避免重复绘制
	 */
	private var __twistyDrawnColor:Int = -1;

	override function onInit() {
		super.onInit();
		// 背景块保持可点击，作为整行的点击热区，未高亮时以全透明显示
		this.addChild(this.backgroundQuad);
		this.twisty.mouseEnabled = false;
		this.addChild(this.twisty);
		this.addChild(this.label);
	}

	private function get_hovered():Bool {
		return __hovered;
	}

	private function set_hovered(value:Bool):Bool {
		if (__hovered == value) {
			return value;
		}
		__hovered = value;
		this.__updateBackground();
		return value;
	}

	override function setData(value:Dynamic) {
		super.setData(value);
		this.hovered = false;
		var row:TreeRowData = value;
		var rowHeight = this.tree != null ? this.tree.rowHeight : 22;
		var indent = this.tree != null ? this.tree.indent : 16;
		var twistySize = this.tree != null ? this.tree.twistySize : 16;
		if (this.tree != null) {
			this.label.fontSize = this.tree.fontSize;
			this.label.color = this.tree.labelColor;
		}
		this.label.data = row.item.label;

		// 文本与文件夹的箭头对齐：叶子节点在箭头位置留白（VSCode对齐方式）
		this.label.x = row.depth * indent + twistySize;
		this.label.y = (rowHeight - this.label.height) / 2;
		this.twisty.visible = row.item.isFolder;
		this.twisty.x = row.depth * indent + twistySize / 2;
		this.twisty.y = rowHeight / 2;
		// 折叠时箭头向右，展开时旋转为向下
		this.twisty.rotation = row.item.expanded ? 90 : 0;
		this.__drawTwisty();
	}

	override function setSelected(selected:Bool) {
		this.__updateBackground();
	}

	override function updateLayout() {
		// 行背景始终撑满整行
		this.backgroundQuad.width = this.width;
		this.backgroundQuad.height = this.height;
		super.updateLayout();
	}

	private function __updateBackground():Void {
		if (this.selected) {
			this.backgroundQuad.alpha = 1;
			this.backgroundQuad.data = this.tree != null ? this.tree.selectionColor : 0x04395E;
		} else if (this.__hovered) {
			this.backgroundQuad.alpha = 1;
			this.backgroundQuad.data = this.tree != null ? this.tree.hoverColor : 0x2A2D2E;
		} else {
			// 渲染时会跳过alpha == 0的对象，同时它仍然参与命中测试，保证整行可点击
			this.backgroundQuad.alpha = 0;
		}
	}

	private function __drawTwisty():Void {
		var color = this.tree != null ? this.tree.twistyColor : 0xCCCCCC;
		if (this.__twistyDrawnColor == color) {
			return;
		}
		this.__twistyDrawnColor = color;
		// 以原点为中心的右指三角形，展开状态由rotation旋转得到
		this.twisty.clear();
		this.twisty.beginFill(color);
		this.twisty.drawTriangles([-2.5, -4, 2.5, 0, -2.5, 4], [0, 1, 2], [0, 0, 1, 0, 0, 1]);
	}
}
