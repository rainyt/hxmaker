package hx.display;

import haxe.Timer;
import hx.events.Event;
import hx.events.Keyboard;
import hx.events.MouseEvent;
import hx.geom.Point;
import hx.layout.ILayout;
import hx.layout.IVirtualLayout;
import hx.layout.VerticalLayout;
import hx.layout.VirtualVerticalLayout;
import hx.utils.KeyboardTools;

/**
 * 树列表，类似VSCode资源管理器的树形列表
 *
 * `Tree`继承自`Scroll`，通过`data`设置根节点（`TreeItem`），支持展开/折叠、单选与多选、悬停高亮与滚动定位，
 * 默认渲染器`TreeItemRenderer`提供展开箭头（twisty）、缩进与文本展示，自定义展示时继承`TreeItemRenderer`即可。
 *
 * ### 多选
 *
 * 与VSCode资源管理器一致的选择行为，选择变化时派发`Event.CHANGE`：
 * - 点击：只选中该行
 * - `Ctrl`/`Cmd`+点击：切换单个节点的选中状态（追加/移除多选）
 * - `Shift`+点击：选中锚点到当前行的区间（替换整个选择）
 * - `Ctrl`/`Cmd`+`Shift`+点击：把区间追加到当前选择
 * - 右键：只把未选中的节点改为单选，已选中的节点保留多选（配合右键菜单）
 *
 * 多选结果通过`selectedItems`读取，`selectedItem`是最后交互的主选中项（始终在`selectedItems`中）。
 *
 * ### 虚拟列表
 *
 * 与`ListView`一致，虚拟列表由`layout`的类型决定（`layout is IVirtualLayout`时开启，`virtual`为只读属性）：
 * 只会为可见区域（以及`virtualBufferCount`行缓冲）创建ItemRenderer，没有被渲染的行区域由虚拟布局的占位对象支撑滚动范围，
 * 因此可以承载成千上万个节点，滚动过程中自动复用`itemRendererRecycler`对象池中的ItemRenderer。
 *
 * ```haxe
 * var tree = new Tree();                       // 默认使用VirtualVerticalLayout，虚拟列表默认开启
 * tree.width = 260;
 * tree.height = 400;
 * var src = new TreeItem("src", [new TreeItem("Main.hx"), new TreeItem("Player.hx")], true);
 * tree.data = [src, new TreeItem("assets"), new TreeItem("project.hxml")];
 * tree.addEventListener(Event.CHANGE, () -> trace(tree.selectedItem.label));
 * this.addChild(tree);
 * ```
 *
 * 行高由`rowHeight`决定，虚拟模式下会自动同步到`VirtualVerticalLayout`的`itemSize`；
 * 需要普通模式（全部行都创建ItemRenderer，适合少量数据）时把`layout`设置为`VerticalLayout`即可：
 *
 * ```haxe
 * tree.layout = new VerticalLayout();          // 关闭虚拟列表
 * ```
 *
 * 注意：
 * - 渲染器的`data`为`TreeRowData`结构（`item`为节点，`depth`为层级深度）
 * - 直接修改`TreeItem.children`后需要调用`refresh()`通知树刷新
 * - 行的宽度始终撑满列表，请保证行渲染器的实际高度不超过`rowHeight`，否则相邻行会重叠
 */
@:keep
class Tree extends Scroll {
	/**
	 * 节点展开事件，`event.data`为展开的`TreeItem`
	 */
	public inline static var ITEM_EXPANDED:String = "itemExpanded";

	/**
	 * 节点折叠事件，`event.data`为折叠的`TreeItem`
	 */
	public inline static var ITEM_COLLAPSED:String = "itemCollapsed";

	/**
	 * 树数据源（根节点列表）
	 */
	public var data(get, set):Array<TreeItem>;

	private var __data:Array<TreeItem>;

	/**
	 * Item渲染器
	 */
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic>;

	/**
	 * 当前是否为虚拟列表
	 *
	 * 当`layout`是虚拟布局（实现了`IVirtualLayout`，例如`VirtualVerticalLayout`）时自动开启：
	 * 只会为可见区域（以及`virtualBufferCount`行缓冲）创建ItemRenderer，没有被渲染的行区域由布局的占位对象支撑滚动范围，
	 * 因此可以承载成千上万个节点，滚动过程中会自动复用`itemRendererRecycler`对象池中的ItemRenderer。
	 *
	 * 注意：`virtual`是只读属性，由`layout`的类型自动决定，不需要也不允许手动开启
	 */
	public var virtual(get, never):Bool;

	/**
	 * 虚拟列表在可视区域上下额外渲染的行数，可以减少快速滑动时的空白，默认`1`
	 */
	public var virtualBufferCount:Int = 1;

	/**
	 * 单行的行高，需要大于`0`，默认`22`
	 *
	 * 虚拟模式下该值会自动同步到`VirtualVerticalLayout`的`itemSize`；反之在`layout`为`VirtualVerticalLayout`时，
	 * 以布局的`itemSize`为准
	 */
	public var rowHeight(get, set):Float;

	private var __rowHeight:Float = 22;

	/**
	 * 每一级层级的缩进尺寸，默认`16`
	 */
	public var indent(get, set):Float;

	private var __indent:Float = 16;

	/**
	 * 展开箭头（twisty）热区的宽度，同时决定文件夹文本的缩进起点，默认`16`
	 */
	public var twistySize(get, set):Float;

	private var __twistySize:Float = 16;

	/**
	 * 默认渲染器的文本字号，默认`13`
	 */
	public var fontSize(get, set):Int;

	private var __fontSize:Int = 13;

	/**
	 * 默认渲染器的文本颜色，默认`0xCCCCCC`（VSCode暗色主题前景色）
	 */
	public var labelColor(get, set):Int;

	private var __labelColor:Int = 0xCCCCCC;

	/**
	 * 选中行背景颜色，默认`0x04395E`（VSCode暗色主题选中色）
	 */
	public var selectionColor(get, set):Int;

	private var __selectionColor:Int = 0x04395E;

	/**
	 * 悬停行背景颜色，默认`0x2A2D2E`（VSCode暗色主题悬停色）
	 */
	public var hoverColor(get, set):Int;

	private var __hoverColor:Int = 0x2A2D2E;

	/**
	 * 展开箭头颜色，默认`0xCCCCCC`
	 */
	public var twistyColor(get, set):Int;

	private var __twistyColor:Int = 0xCCCCCC;

	/**
	 * 点击文件夹行时是否同时切换展开状态（VSCode资源管理器行为），默认`true`
	 */
	public var toggleFolderOnClick:Bool = true;

	/**
	 * 是否允许右键点击来选择
	 */
	public var rightClickSelectEnabled:Bool = true;

	/**
	 * 当前选中的行索引（可见行的扁平索引，展开状态变化后会自动跟随选中项偏移）
	 */
	public var selectedIndex(get, set):Int;

	private var __selectedIndex:Int = -1;

	/**
	 * 当前选中的节点（主选中项，最后交互的节点），祖先被折叠时节点仍然保持选中（行不可见），`null`表示未选中
	 */
	public var selectedItem(get, set):TreeItem;

	private var __selectedItem:TreeItem;

	/**
	 * 多选的节点集合（保持选择的先后顺序），`__selectedItem`始终在集合中
	 */
	private var __selectedItems:Array<TreeItem> = [];

	/**
	 * Shift+点击范围选择的锚点行对应的节点
	 */
	private var __selectionAnchor:TreeItem = null;

	private var __selectedDirty:Bool = false;

	// ============================== 虚拟列表 ==============================

	/**
	 * 当前的虚拟布局，`null`表示`layout`不是虚拟布局
	 */
	private var __virtualLayout:IVirtualLayout = null;

	/**
	 * 扁平化后的可见行，只包含展开路径上的节点
	 */
	private var __rows:Array<TreeRowData> = [];

	/**
	 * 展开状态或数据发生变化，需要重新扁平化
	 */
	private var __rowsDirty:Bool = true;

	/**
	 * 需要重新绑定Item的数据
	 */
	private var __dataDirty:Bool = true;

	/**
	 * 行索引与ItemRenderer的映射（虚拟列表）
	 */
	private var __items:Map<Int, DisplayObject> = new Map();

	/**
	 * 虚拟布局的占位对象，它不属于ItemRenderer，不能回收到Item的对象池中
	 */
	private var __spacer:DisplayObject = null;

	/**
	 * 可见的行索引区间，`last`小于`first`时表示没有数据
	 */
	private var __range:{first:Int, last:Int} = {first: -1, last: -1};

	/**
	 * 最近一次渲染的可见行索引区间
	 */
	private var __lastFirst:Int = -1;

	private var __lastLast:Int = -1;

	/**
	 * 最近一次渲染时的行总量与内容尺寸
	 */
	private var __lastTotal:Int = -1;

	private var __lastContentSize:Float = -1;

	/**
	 * 最近一次渲染时列表的尺寸，用于检测列表尺寸变化
	 */
	private var __lastWidth:Float = -1;

	private var __lastHeight:Float = -1;

	/**
	 * 虚拟列表是否已接管子对象
	 */
	private var __virtualReady:Bool = false;

	/**
	 * 当前悬停的ItemRenderer
	 */
	private var __hoverRenderer:DisplayObject = null;

	public function new() {
		super();
	}

	override function onInit() {
		super.onInit();
		this.itemRendererRecycler = DisplayObjectRecycler.withClass(TreeItemRenderer);
		// 默认虚拟列表，与ListView一样可以通过layout切换普通模式
		this.layout = new VirtualVerticalLayout(this.__rowHeight);
		this.addEventListener(MouseEvent.CLICK, onRowClick);
		this.addEventListener(MouseEvent.RIGHT_CLICK, onRowClick);
		this.addEventListener(MouseEvent.MOUSE_OVER, onRowMouseOver);
		this.addEventListener(MouseEvent.MOUSE_OUT, onRowMouseOut);
		this.scrollXEnable = false;
	}

	private function get_data():Array<TreeItem> {
		return __data;
	}

	private function set_data(value:Array<TreeItem>):Array<TreeItem> {
		this.__data = value;
		this.refresh();
		return value;
	}

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic>):DisplayObjectRecycler<Dynamic> {
		if (this.itemRendererRecycler == value) {
			return value;
		}
		// 切换渲染器后旧渲染器不能再进入新的对象池，全部回收重建
		this.__clearChildren();
		this.itemRendererRecycler = value;
		this.__dataDirty = true;
		this.invalidate();
		return value;
	}

	private function get_virtual():Bool {
		return this.__virtualLayout != null;
	}

	override function set_layout(value:ILayout):ILayout {
		var result = super.set_layout(value);
		this.__virtualLayout = value is IVirtualLayout ? cast value : null;
		// Tree的行宽始终撑满列表
		if (value is VerticalLayout) {
			cast(value, VerticalLayout).horizontalFill = true;
		}
		// 虚拟纵向布局的itemSize与rowHeight保持一致，以布局声明的值为准
		if (value is VirtualVerticalLayout) {
			this.__rowHeight = cast(value, VirtualVerticalLayout).itemSize;
		}
		this.__dataDirty = true;
		this.invalidate();
		return result;
	}

	private function get_rowHeight():Float {
		return __rowHeight;
	}

	private function set_rowHeight(value:Float):Float {
		if (__rowHeight != value) {
			__rowHeight = value;
			if (this.__virtualLayout != null && this.__virtualLayout is VirtualVerticalLayout) {
				cast(this.__virtualLayout, VirtualVerticalLayout).itemSize = value;
			}
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_indent():Float {
		return __indent;
	}

	private function set_indent(value:Float):Float {
		if (__indent != value) {
			__indent = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_twistySize():Float {
		return __twistySize;
	}

	private function set_twistySize(value:Float):Float {
		if (__twistySize != value) {
			__twistySize = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_fontSize():Int {
		return __fontSize;
	}

	private function set_fontSize(value:Int):Int {
		if (__fontSize != value) {
			__fontSize = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_labelColor():Int {
		return __labelColor;
	}

	private function set_labelColor(value:Int):Int {
		if (__labelColor != value) {
			__labelColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_selectionColor():Int {
		return __selectionColor;
	}

	private function set_selectionColor(value:Int):Int {
		if (__selectionColor != value) {
			__selectionColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_hoverColor():Int {
		return __hoverColor;
	}

	private function set_hoverColor(value:Int):Int {
		if (__hoverColor != value) {
			__hoverColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_twistyColor():Int {
		return __twistyColor;
	}

	private function set_twistyColor(value:Int):Int {
		if (__twistyColor != value) {
			__twistyColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	/**
	 * 数据或展开状态发生变化后手动通知刷新
	 */
	public function refresh():Void {
		this.__rowsDirty = true;
		this.__dataDirty = true;
		this.invalidate();
	}

	// ============================== 选择 ==============================

	private function get_selectedIndex():Int {
		this.__ensureRows();
		return this.__selectedIndex;
	}

	private function set_selectedIndex(value:Int):Int {
		this.__ensureRows();
		this.__selectSingleItem(value >= 0 && value < this.__rows.length ? this.__rows[value].item : null);
		return value;
	}

	private function get_selectedItem():TreeItem {
		return this.__selectedItem;
	}

	private function set_selectedItem(value:TreeItem):TreeItem {
		// 允许选中隐藏（祖先折叠）的节点，行索引可能为-1
		this.__selectSingleItem(value);
		return value;
	}

	/**
	 * 当前选中的全部节点（多选，保持选择的先后顺序）
	 *
	 * `selectedItem`是最后交互的主选中项，它始终在选中集合中；请勿直接修改返回的数组，
	 * 程序化修改请使用`selectedItem`与`clearSelection()`
	 */
	public var selectedItems(get, never):Array<TreeItem>;

	private function get_selectedItems():Array<TreeItem> {
		return this.__selectedItems;
	}

	/**
	 * 清除选中状态
	 */
	public function clearSelection():Void {
		this.__selectSingleItem(null);
	}

	/**
	 * 单选语义：清空多选集合，只选中一个节点，并把Shift+点击的锚点设置到该节点
	 */
	private function __selectSingleItem(item:TreeItem):Void {
		this.__ensureRows();
		var same = this.__selectedItems.length == 1 && this.__selectedItems[0] == item;
		this.__selectedItem = item;
		this.__selectionAnchor = item;
		this.__selectedIndex = item != null ? this.__getRowOfItem(item) : -1;
		this.__selectedItems.resize(0);
		if (item != null) {
			this.__selectedItems.push(item);
		}
		if (!same) {
			this.__selectedDirty = true;
			this.invalidate();
			this.dispatchEvent(new Event(Event.CHANGE));
		}
	}

	/**
	 * 节点是否在选中集合中
	 */
	private function __isSelected(item:TreeItem):Bool {
		return item != null && this.__selectedItems.indexOf(item) >= 0;
	}

	/**
	 * 把节点加入/移出选中集合
	 */
	private function __setItemSelected(item:TreeItem, selected:Bool):Void {
		if (item == null) {
			return;
		}
		var index = this.__selectedItems.indexOf(item);
		if (selected && index < 0) {
			this.__selectedItems.push(item);
		} else if (!selected && index >= 0) {
			this.__selectedItems.splice(index, 1);
		}
	}

	// ============================== 展开/折叠 ==============================

	/**
	 * 展开节点
	 * @param item 目标节点
	 * @param recursive 是否同时展开全部后代节点
	 */
	public function expandItem(item:TreeItem, recursive:Bool = false):Void {
		this.__setItemExpanded(item, true, recursive);
	}

	/**
	 * 折叠节点
	 * @param item 目标节点
	 * @param recursive 是否同时折叠全部后代节点
	 */
	public function collapseItem(item:TreeItem, recursive:Bool = false):Void {
		this.__setItemExpanded(item, false, recursive);
	}

	/**
	 * 切换节点的展开状态
	 */
	public function toggleItem(item:TreeItem):Void {
		if (item == null) {
			return;
		}
		this.__setItemExpanded(item, !item.expanded, false);
	}

	/**
	 * 节点是否处于展开状态
	 */
	public function isItemExpanded(item:TreeItem):Bool {
		return item != null && item.isFolder && item.expanded;
	}

	/**
	 * 展开全部节点
	 */
	public function expandAll():Void {
		if (this.__data == null) {
			return;
		}
		for (item in this.__data) {
			this.__setItemExpanded(item, true, true);
		}
	}

	/**
	 * 折叠全部节点
	 */
	public function collapseAll():Void {
		if (this.__data == null) {
			return;
		}
		for (item in this.__data) {
			this.__setItemExpanded(item, false, true);
		}
	}

	private function __setItemExpanded(item:TreeItem, expanded:Bool, recursive:Bool):Void {
		if (item == null || !item.isFolder || item.expanded == expanded) {
			return;
		}
		if (recursive) {
			this.__setDescendantsExpanded(item, expanded);
		}
		item.expanded = expanded;
		this.__rowsDirty = true;
		this.invalidate();
		this.dispatchEvent(new Event(expanded ? ITEM_EXPANDED : ITEM_COLLAPSED, false, false, item));
	}

	private function __setDescendantsExpanded(item:TreeItem, expanded:Bool):Void {
		if (item.children == null) {
			return;
		}
		for (child in item.children) {
			if (child.isFolder) {
				child.expanded = expanded;
				this.__setDescendantsExpanded(child, expanded);
			}
		}
	}

	// ============================== 定位与查询 ==============================

	/**
	 * 滚动到指定节点使其可见，节点因祖先折叠而不可见时会先自动展开祖先（类似VSCode的`reveal`）
	 * @param item 目标节点
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToItem(item:TreeItem, duration:Float = 0.2):Void {
		if (item == null) {
			return;
		}
		var row = this.getRowOfItem(item);
		if (row < 0) {
			// 沿父节点链逐级展开，让目标节点出现在可见行中
			var chain:Array<TreeItem> = [];
			var parent = item.parent;
			while (parent != null) {
				chain.unshift(parent);
				parent = parent.parent;
			}
			for (ancestor in chain) {
				this.__setItemExpanded(ancestor, true, false);
			}
			row = this.getRowOfItem(item);
		}
		if (row < 0) {
			return;
		}
		// 最小滚动距离，让目标行完整出现在可视区域内
		var offset = this.__getRowOffset(row);
		var current = -this.scrollY;
		var targetY = this.scrollY;
		if (offset < current) {
			targetY = -offset;
		} else if (offset + this.__rowHeight > current + this.height) {
			targetY = -(offset + this.__rowHeight - this.height);
		}
		if (duration <= 0) {
			var data = getMoveingToData({scrollX: this.scrollX, scrollY: targetY});
			this.scrollX = data.scrollX;
			this.scrollY = data.scrollY;
		} else {
			this.scrollTo(this.scrollX, targetY, duration);
		}
	}

	/**
	 * 滚动到指定的行索引
	 * @param index 可见行的扁平索引
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToIndex(index:Int, duration:Float = 0.2):Void {
		this.__ensureRows();
		if (index < 0 || index >= this.__rows.length) {
			return;
		}
		var y = -this.__getRowOffset(index);
		if (duration <= 0) {
			var data = getMoveingToData({scrollX: this.scrollX, scrollY: y});
			this.scrollX = data.scrollX;
			this.scrollY = data.scrollY;
		} else {
			this.scrollTo(this.scrollX, y, duration);
		}
	}

	/**
	 * 获得指定行的节点
	 * @param row 可见行的扁平索引
	 * @return TreeItem 行不存在时返回`null`
	 */
	public function getItemAt(row:Int):TreeItem {
		this.__ensureRows();
		return row >= 0 && row < this.__rows.length ? this.__rows[row].item : null;
	}

	/**
	 * 当前的可见行数量（展开路径扁平化后的行数，随展开/折叠变化）
	 */
	public var rowCount(get, never):Int;

	private function get_rowCount():Int {
		this.__ensureRows();
		return this.__rows.length;
	}

	/**
	 * 获得节点所在的行索引，节点不可见（自身或祖先被折叠）时返回`-1`
	 */
	public function getRowOfItem(item:TreeItem):Int {
		if (item == null) {
			return -1;
		}
		this.__ensureRows();
		for (row in 0...this.__rows.length) {
			if (this.__rows[row].item == item) {
				return row;
			}
		}
		return -1;
	}

	/**
	 * 获得显示对象对应的节点，用于自定义事件（右键菜单、双击打开等）中把`event.target`映射为数据
	 * @param child 事件目标或者它的任意子显示对象
	 * @return TreeItem 不在行上时返回`null`
	 */
	public function getItemByRenderer(child:DisplayObject):TreeItem {
		this.__ensureRows();
		var renderer = this.__getRendererFromChild(child);
		if (renderer == null || renderer == this.__spacer) {
			return null;
		}
		var row = this.__getRowIndexByRenderer(renderer);
		return row >= 0 ? this.__rows[row].item : null;
	}

	/**
	 * 获得指定行在主轴方向上的起始位置
	 */
	private function __getRowOffset(row:Int):Float {
		if (this.virtual) {
			return this.__virtualLayout.getItemOffset(row);
		}
		var child = this.getChildAt(row);
		return child != null ? child.y : row * this.__rowHeight;
	}

	// ============================== 交互 ==============================

	private function onRowClick(e:MouseEvent):Void {
		if (e.type == MouseEvent.RIGHT_CLICK && !this.rightClickSelectEnabled) {
			return;
		}
		this.__ensureRows();
		var renderer = this.__getRendererFromChild(cast e.target);
		if (renderer == null || renderer == this.__spacer) {
			return;
		}
		var row = this.__getRowIndexByRenderer(renderer);
		if (row < 0) {
			return;
		}
		var rowData = this.__rows[row];
		// 点击在展开箭头热区上时只切换展开状态，不改变选择（VSCode行为）
		var localX = renderer.globalToLocal(new Point(e.stageX, e.stageY)).x;
		var twistyStart = rowData.depth * this.indent;
		if (rowData.item.isFolder && localX >= twistyStart && localX < twistyStart + this.twistySize) {
			this.toggleItem(rowData.item);
			return;
		}
		// 右键：只把未选中的节点改为单选，已选中的保留多选（VSCode行为，配合右键菜单）
		if (e.type == MouseEvent.RIGHT_CLICK) {
			if (!this.__isSelected(rowData.item)) {
				this.__selectSingleItem(rowData.item);
			}
			return;
		}
		if (e.isCtrlOrCommand) {
			// Ctrl/Cmd+点击：切换单个节点的选中状态，范围选择的锚点移动到该行
			var selected = !this.__isSelected(rowData.item);
			this.__setItemSelected(rowData.item, selected);
			if (selected) {
				this.__selectedItem = rowData.item;
			} else if (this.__selectedItem == rowData.item) {
				// 主选中项始终保持在选中集合中，被取消时转移到最近一次选中的节点
				this.__selectedItem = this.__selectedItems.length > 0 ? this.__selectedItems[this.__selectedItems.length - 1] : null;
			}
			this.__selectionAnchor = rowData.item;
			this.__selectedIndex = this.__selectedItem != null ? this.getRowOfItem(this.__selectedItem) : -1;
			this.__selectedDirty = true;
			this.invalidate();
			this.dispatchEvent(new Event(Event.CHANGE));
			return;
		}
		if (KeyboardTools.isKeyDown(Keyboard.SHIFT)) {
			// Shift+点击：选中锚点到当前行的区间，Ctrl+Shift为追加区间，Shift为替换整个选择
			var anchorRow = this.__selectionAnchor != null ? this.getRowOfItem(this.__selectionAnchor) : -1;
			if (anchorRow < 0) {
				anchorRow = row;
			}
			var from = anchorRow < row ? anchorRow : row;
			var to = anchorRow < row ? row : anchorRow;
			if (!e.isCtrlOrCommand) {
				this.__selectedItems.resize(0);
			}
			for (r in from...to + 1) {
				this.__setItemSelected(this.__rows[r].item, true);
			}
			this.__selectedItem = rowData.item;
			this.__selectedIndex = row;
			this.__selectedDirty = true;
			this.invalidate();
			this.dispatchEvent(new Event(Event.CHANGE));
			return;
		}
		// 普通点击：只选中该行；文件夹默认同时切换展开状态
		this.__selectSingleItem(rowData.item);
		if (rowData.item.isFolder && this.toggleFolderOnClick) {
			this.toggleItem(rowData.item);
		}
	}

	private function onRowMouseOver(e:MouseEvent):Void {
		var renderer = this.__getRendererFromChild(cast e.target);
		if (renderer == null || renderer == this.__spacer || renderer == this.__hoverRenderer) {
			return;
		}
		this.__setHoverRenderer(renderer);
	}

	private function onRowMouseOut(e:MouseEvent):Void {
		if (this.__hoverRenderer == null) {
			return;
		}
		var renderer = this.__getRendererFromChild(cast e.target);
		if (renderer == this.__hoverRenderer) {
			this.__setHoverRenderer(null);
		}
	}

	private function __setHoverRenderer(renderer:DisplayObject):Void {
		if (this.__hoverRenderer != null && this.__hoverRenderer is TreeItemRenderer) {
			cast(this.__hoverRenderer, TreeItemRenderer).hovered = false;
		}
		this.__hoverRenderer = renderer;
		if (renderer != null && renderer is TreeItemRenderer) {
			cast(renderer, TreeItemRenderer).hovered = true;
		}
	}

	/**
	 * 从事件目标向上找到挂在内容容器上的ItemRenderer
	 */
	private function __getRendererFromChild(child:DisplayObject):DisplayObject {
		var current:DisplayObject = child;
		while (current != null && current.parent != this.box) {
			current = current.parent;
		}
		return current;
	}

	/**
	 * 获得ItemRenderer对应的行索引，虚拟列表的子对象索引与行索引并不一致
	 */
	private function __getRowIndexByRenderer(renderer:DisplayObject):Int {
		if (this.virtual) {
			for (index => item in this.__items) {
				if (item == renderer) {
					return index;
				}
			}
			return -1;
		}
		var index = this.getChildIndexAt(renderer);
		return index >= 0 && index < this.__rows.length ? index : -1;
	}

	// ============================== 渲染 ==============================

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (this.virtual) {
			// 虚拟列表：由虚拟布局排列Item与占位对象
			this.__updateVirtual();
			return;
		}
		this.__updateNormal();
	}

	/**
	 * 普通模式渲染，为全部可见行创建ItemRenderer
	 */
	private function __updateNormal():Void {
		if (this.__rowsDirty) {
			// 行集合变化等同于数据变化，整体重建
			this.__reflatRows();
			this.__dataDirty = true;
		}
		if (this.__virtualReady) {
			// 虚拟布局已经被替换为普通布局，清理虚拟列表创建的子对象
			this.__clearChildren();
		}
		var dataDirty = this.__dataDirty;
		var selectedDirty = this.__selectedDirty || dataDirty;
		this.__dataDirty = false;
		this.__selectedDirty = false;
		if (!dataDirty && !selectedDirty) {
			return;
		}
		if (dataDirty) {
			this.__clearChildren();
			for (row in 0...this.__rows.length) {
				var renderer = this.itemRendererRecycler.create();
				this.addChild(renderer);
				if (renderer is TreeItemRenderer) {
					cast(renderer, TreeItemRenderer).tree = this;
				}
				renderer.height = this.__rowHeight;
				this.__setRendererData(renderer, row);
				this.__setRendererSelected(renderer, row);
			}
			if (this.autoVisible) {
				Timer.delay(this.invalidate, 16);
			}
		} else {
			// 只刷新全部行的选中状态
			for (row in 0...this.numChildren) {
				var renderer = this.getChildAt(row);
				if (renderer != null) {
					this.__setRendererSelected(renderer, row);
				}
			}
		}
		this.updateLayout();
	}

	/**
	 * 虚拟列表渲染，只为可见区域创建ItemRenderer
	 *
	 * 数据的可见区间、Item的位置与尺寸、占位对象都由虚拟布局负责，`Tree`只负责ItemRenderer的创建、回收与数据绑定
	 */
	private function __updateVirtual():Void {
		var layout = this.__virtualLayout;
		var rowsDirty = this.__rowsDirty;
		if (rowsDirty) {
			this.__reflatRows();
		}
		var total = this.__rows.length;
		// 先把可见Item与行总量同步给布局，布局的内容尺寸与可见区间都以它为准
		layout.setItems(this.__items, total);
		var contentSize = layout.contentSize;
		var offset = layout.horizontal ? -this.scrollX : -this.scrollY;
		var viewport = layout.horizontal ? this.width : this.height;
		layout.getVisibleRange(this.__range, total, offset, viewport, this.virtualBufferCount);
		var first = this.__range.first;
		var last = this.__range.last;

		// 展开状态变化会移动行的位置，所有可见Item都需要重新绑定数据与选中状态
		var dataDirty = this.__dataDirty || rowsDirty;
		var selectedDirty = this.__selectedDirty || dataDirty;
		this.__dataDirty = false;
		this.__selectedDirty = false;

		// 可见区间、数据、内容尺寸与列表尺寸都没有变化时，不需要刷新
		if (!dataDirty
			&& !selectedDirty
			&& contentSize == this.__lastContentSize
			&& total == this.__lastTotal
			&& first == this.__lastFirst
			&& last == this.__lastLast
			&& !this.__virtualSizeChanged()) {
			return;
		}
		if (!this.__virtualReady) {
			// 由普通模式进入虚拟模式时需要先清理普通模式创建的全部ItemRenderer
			this.__clearChildren();
		}
		if (rowsDirty && this.__hoverRenderer != null) {
			// 行位置已经发生变化，悬停高亮等待下一次鼠标移动重新计算
			this.__setHoverRenderer(null);
		}

		// 回收可见区间之外的ItemRenderer
		var expired:Array<Int> = [];
		for (index in this.__items.keys()) {
			if (index < first || index > last) {
				expired.push(index);
			}
		}
		for (index in expired) {
			var renderer = this.__items.get(index);
			this.__items.remove(index);
			if (renderer == this.__hoverRenderer) {
				this.__setHoverRenderer(null);
			}
			renderer.parent.removeChild(renderer);
			this.itemRendererRecycler.release(renderer);
		}

		// 创建（或者复用对象池中的）ItemRenderer，并绑定数据
		for (index in first...last + 1) {
			var renderer = this.__items.get(index);
			var isNewRenderer = renderer == null;
			if (isNewRenderer) {
				renderer = this.itemRendererRecycler.create();
				this.__items.set(index, renderer);
				this.addChild(renderer);
				if (renderer is TreeItemRenderer) {
					cast(renderer, TreeItemRenderer).tree = this;
				}
			}
			if (isNewRenderer || dataDirty) {
				renderer.height = this.__rowHeight;
				this.__setRendererData(renderer, index);
			}
			if (isNewRenderer || selectedDirty) {
				this.__setRendererSelected(renderer, index);
			}
		}

		// 行的位置与尺寸、占位对象的内容尺寸都交给虚拟布局计算
		var spacer = layout.spacer;
		if (spacer.parent == null) {
			this.addChild(spacer);
		}
		this.__spacer = spacer;

		this.__lastFirst = first;
		this.__lastLast = last;
		this.__lastTotal = total;
		this.__lastContentSize = contentSize;
		this.__lastWidth = this.width;
		this.__lastHeight = this.height;
		this.updateLayout();

		// 内容尺寸不再由ItemRenderer决定，失效Scroll的内容尺寸缓存
		this.__cachedMaxSize = null;
		this.__virtualReady = true;
	}

	/**
	 * 列表尺寸是否发生变化
	 */
	private function __virtualSizeChanged():Bool {
		return this.__lastWidth != this.width || this.__lastHeight != this.height;
	}

	/**
	 * 把展开路径上的节点扁平化为可见行
	 */
	private function __reflatRows():Void {
		this.__rows.resize(0);
		if (this.__data != null) {
			this.__flattenItems(this.__data, 0);
		}
		this.__rowsDirty = false;
		// 已经不在树中的选中项不再保持选中
		if (this.__selectedItems.length > 0) {
			var i = this.__selectedItems.length;
			while (i-- > 0) {
				if (!this.__isItemAttached(this.__selectedItems[i])) {
					this.__selectedItems.splice(i, 1);
				}
			}
		}
		if (this.__selectedItem != null && !this.__isItemAttached(this.__selectedItem)) {
			this.__selectedItem = null;
		}
		if (this.__selectionAnchor != null && !this.__isItemAttached(this.__selectionAnchor)) {
			this.__selectionAnchor = null;
		}
		this.__selectedIndex = this.__selectedItem != null ? this.__getRowOfItem(this.__selectedItem) : -1;
	}

	private function __flattenItems(items:Array<TreeItem>, depth:Int):Void {
		for (item in items) {
			this.__rows.push({item: item, depth: depth});
			if (item.expanded && item.isFolder) {
				this.__flattenItems(item.children, depth + 1);
			}
		}
	}

	/**
	 * 确保可见行与展开状态同步，查询接口在扁平化之前调用
	 */
	private function __ensureRows():Void {
		if (this.__rowsDirty) {
			this.__reflatRows();
		}
	}

	private function __getRowOfItem(item:TreeItem):Int {
		for (row in 0...this.__rows.length) {
			if (this.__rows[row].item == item) {
				return row;
			}
		}
		return -1;
	}

	/**
	 * 节点是否还挂在数据源的根节点上
	 */
	private function __isItemAttached(item:TreeItem):Bool {
		if (this.__data == null) {
			return false;
		}
		var current = item;
		while (current.parent != null) {
			current = current.parent;
		}
		return this.__data.indexOf(current) >= 0;
	}

	/**
	 * 绑定ItemRenderer的行数据
	 */
	private function __setRendererData(renderer:DisplayObject, index:Int):Void {
		if (renderer is IDataProider) {
			var proider:IDataProider<Dynamic> = cast renderer;
			proider.data = this.__rows[index];
		}
	}

	/**
	 * 绑定ItemRenderer的选中状态
	 */
	private function __setRendererSelected(renderer:DisplayObject, index:Int):Void {
		if (renderer is ISelectProider) {
			var proider:ISelectProider = cast renderer;
			proider.selected = index >= 0 && index < this.__rows.length && this.__isSelected(this.__rows[index].item);
		}
	}

	/**
	 * 清理树创建的所有子对象，全部回收到ItemRenderer的对象池
	 */
	private function __clearChildren():Void {
		var i = this.children.length;
		while (i-- > 0) {
			var child = this.children[i];
			if (child == this.__hoverRenderer) {
				this.__setHoverRenderer(null);
			}
			if (child.parent != null) {
				child.parent.removeChild(child);
			}
			if (child == this.__spacer) {
				// 占位对象不是ItemRenderer，不能放进对象池
				continue;
			}
			this.itemRendererRecycler.release(child);
		}
		this.__spacer = null;
		// 虚拟布局持有该Map的引用，只清空不替换
		this.__items.clear();
		this.__lastFirst = -1;
		this.__lastLast = -1;
		this.__lastTotal = -1;
		this.__lastContentSize = -1;
		this.__lastWidth = -1;
		this.__lastHeight = -1;
		this.__virtualReady = false;
	}
}
