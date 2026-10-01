package hx.display;

/**
 * 默认的`FinderView`行渲染器，提供选中/悬停背景、类型图标（文件夹/文件）与文本展示
 *
 * 自定义渲染器继承`FinderItemRenderer`后，图标与选中/悬停背景会自动维护，
 * 只需要在`setData`中处理自定义内容；`data`为`TreeRowData`结构（`item`为节点，`depth`恒为`0`），
 * 与`Tree`的行数据同构，因此自定义渲染器可以在`Tree`与`FinderView`之间共享。
 */
@:keep
class FinderItemRenderer extends ItemRenderer {
	/**
	 * 所属的资源选择器，由`FinderView`在创建渲染器时设置，样式参数从中读取
	 */
	public var finder:FinderView = null;

	/**
	 * 节点文本
	 */
	public var label:Label = new Label();

	/**
	 * 类型图标，文件夹与文件分别绘制（颜色由`FinderView.folderColor`与`fileColor`决定）
	 */
	public var icon:Graphics = new Graphics();

	/**
	 * 行背景，选中与悬停时可见
	 *
	 * 它同时作为整行的点击热区：未高亮时保持显示但`alpha = 0`（渲染时会跳过`alpha == 0`的对象，不产生绘制开销），
	 * 高亮时`alpha = 1`。请勿将它设置为不可见或关闭鼠标事件，否则点击行的空白区域将无法命中
	 */
	public var backgroundQuad:Quad = new Quad(0, 0, 0xffffff);

	private var __hovered:Bool = false;

	/**
	 * 是否处于悬停状态，由`FinderView`维护
	 */
	public var hovered(get, set):Bool;

	/**
	 * 图标左侧的留白
	 */
	public static inline var PADDING_LEFT:Float = 4;

	/**
	 * 图标与文本之间的间距
	 */
	public static inline var ICON_GAP:Float = 6;

	/**
	 * 最近一次绘制图标使用的颜色与形状，避免重复绘制
	 */
	private var __iconDrawnColor:Int = -1;

	private var __iconDrawnIsFolder:Bool = false;

	override function onInit() {
		super.onInit();
		// 背景块保持可点击，作为整行的点击热区，未高亮时以全透明显示
		this.addChild(this.backgroundQuad);
		// 图标与文本不参与命中，保证整行双击都能命中到backgroundQuad（双击由FinderView处理）
		this.icon.mouseEnabled = false;
		this.addChild(this.icon);
		this.label.mouseEnabled = false;
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
		var rowHeight = this.finder != null ? this.finder.rowHeight : 22;
		var iconSize = this.finder != null ? this.finder.iconSize : 14;
		if (this.finder != null) {
			this.label.fontSize = this.finder.fontSize;
			this.label.color = this.finder.labelColor;
		}
		this.label.data = row.item.label;
		// `..`行（返回上一级行）不是文件夹节点，但也按文件夹图标绘制
		var isParent = this.finder != null && row.item == this.finder.parentItem;
		this.icon.x = PADDING_LEFT;
		this.icon.y = (rowHeight - iconSize) / 2;
		this.label.x = PADDING_LEFT + iconSize + ICON_GAP;
		this.label.y = (rowHeight - this.label.height) / 2;
		this.icon.scaleX = this.icon.scaleY = iconSize / 14;
		this.__drawIcon(row.item.isFolder || isParent);
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
			this.backgroundQuad.data = this.finder != null ? this.finder.selectionColor : 0x04395E;
		} else if (this.__hovered) {
			this.backgroundQuad.alpha = 1;
			this.backgroundQuad.data = this.finder != null ? this.finder.hoverColor : 0x2A2D2E;
		} else {
			// 渲染时会跳过alpha == 0的对象，同时它仍然参与命中测试，保证整行可点击
			this.backgroundQuad.alpha = 0;
		}
	}

	/**
	 * 以`14×14`为基准绘制类型图标（缩放由`setData`根据`iconSize`设置）
	 */
	private function __drawIcon(isFolder:Bool):Void {
		var color = 0x9BA5AE;
		if (this.finder != null) {
			color = isFolder ? this.finder.folderColor : this.finder.fileColor;
		}
		if (this.__iconDrawnColor == color && this.__iconDrawnIsFolder == isFolder) {
			return;
		}
		this.__iconDrawnColor = color;
		this.__iconDrawnIsFolder = isFolder;
		this.icon.clear();
		this.icon.beginFill(color);
		if (isFolder) {
			// 文件夹：左上标签块 + 主体
			this.icon.drawRect(0.5, 1.5, 5.5, 3);
			this.icon.drawRect(0.5, 3.5, 13, 9.5);
		} else {
			// 文件：右上带折角的页面
			this.icon.drawTriangles([1, 0.5, 10, 0.5, 13, 3.5, 13, 13.5, 1, 13.5], [0, 1, 2, 0, 2, 3, 0, 3, 4], [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]);
			this.icon.drawTriangles([10, 0.5, 10, 3.5, 13, 3.5], [0, 1, 2], [0, 0, 1, 0, 0, 1]);
		}
	}
}
