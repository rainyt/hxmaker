package hx.display;

import haxe.Timer;
import hx.events.Event;
import hx.events.Keyboard;
import hx.events.MouseEvent;
import hx.layout.ILayout;
import hx.layout.IVirtualLayout;
import hx.layout.VerticalLayout;
import hx.layout.VirtualVerticalLayout;
import hx.utils.KeyboardTools;

/**
 * 资源选择器，类似Mac访达（Finder）的列表浏览
 *
 * `FinderView`与`Tree`共用`TreeItem`数据模型，但不做树形展开：一次只显示当前目录的一层子项，
 * 单击选中、双击文件夹进入下一级，通过`currentItem`/`goUp()`/`goToRoot()`在目录之间导航，
 * 适合资源浏览器、打开文件对话框等场景。数据源不绑定文件系统，使用方预先构建好`TreeItem`树。
 *
 * ```haxe
 * var finder = new FinderView();
 * finder.width = 260;
 * finder.height = 400;
 * var assets = new TreeItem("assets", [
 *     new TreeItem("audio", [new TreeItem("bgm.ogg")]),
 *     new TreeItem("images"),
 * ]);
 * finder.data = [new TreeItem("src", [new TreeItem("Main.hx")]), assets, new TreeItem("project.hxml")];
 * finder.addEventListener(FinderView.PATH_CHANGED, e -> trace(finder.path));
 * finder.addEventListener(FinderView.ITEM_DOUBLE_CLICKED, e -> trace("打开：" + e.data.label));
 * this.addChild(finder);
 * ```
 *
 * ### 目录导航
 *
 * - 双击文件夹进入下一级（先派发`ITEM_DOUBLE_CLICKED`，进入后派发`PATH_CHANGED`）
 * - `goInto(item)`进入指定文件夹；`goUp()`返回上一级，并像访达一样自动选中刚退出的文件夹；`goToRoot()`回到根层级
 * - `showParentRow`开启（默认）时，非根层级的第一行显示`..`行，双击它返回上一级
 * - `currentItem`为当前目录（`null`表示根层级），`path`是从根到当前目录的节点链，可用于自建面包屑导航
 * - 目录切换后清空选中并回到列表顶部，`PATH_CHANGED`的`event.data`为新目录（根层级为`null`）
 *
 * ### 多选
 *
 * 与`Tree`一致的选择行为，选择变化时派发`Event.CHANGE`：
 * - 点击：只选中该行
 * - `Ctrl`/`Cmd`+点击：切换单个节点的选中状态（追加/移除多选）
 * - `Shift`+点击：选中锚点到当前行的区间（替换整个选择）
 * - `Ctrl`/`Cmd`+`Shift`+点击：把区间追加到当前选择
 * - 右键：只把未选中的节点改为单选，已选中的节点保留多选（配合右键菜单）
 *
 * 选择只在当前目录内有效，切换目录后自动清空。
 *
 * ### 虚拟列表
 *
 * 与`Tree`/`ListView`一致，虚拟列表由`layout`的类型决定（`layout is IVirtualLayout`时开启，`virtual`为只读属性）：
 * 只会为可见区域（以及`virtualBufferCount`行缓冲）创建ItemRenderer，滚动过程中自动复用`itemRendererRecycler`对象池中的ItemRenderer。
 *
 * 注意：
 * - 渲染器的`data`为`TreeRowData`结构（`depth`恒为`0`），与`Tree`的行数据同构，自定义渲染器可以在两者之间共享
 * - 直接修改`TreeItem.children`后需要调用`refresh()`通知刷新；当前目录被移出数据源时自动回到根层级
 * - `showParentRow`开启且不在根层级时，第一行是`..`行（哨兵节点`parentItem`），它计入`rowCount`且可以被选中，
 *   但它不是数据源中的节点，目录切换后选中会自动清除
 * - 行的宽度始终撑满列表，请保证行渲染器的实际高度不超过`rowHeight`，否则相邻行会重叠
 */
@:keep
class FinderView extends Scroll {
	/**
	 * 行被双击事件，`event.data`为被双击的`TreeItem`（双击文件时可用作"打开/确认"的钩子，双击文件夹随后自动进入）
	 */
	public inline static var ITEM_DOUBLE_CLICKED:String = "itemDoubleClicked";

	/**
	 * 当前目录变化事件，`event.data`为新的目录节点，根层级时为`null`
	 */
	public inline static var PATH_CHANGED:String = "pathChanged";

	/**
	 * 数据源（根节点列表）
	 */
	public var data(get, set):Array<TreeItem>;

	private var __data:Array<TreeItem>;

	/**
	 * 当前所在的目录节点，`null`表示根层级（显示`data`的内容）
	 */
	public var currentItem(get, set):TreeItem;

	private var __currentItem:TreeItem = null;

	/**
	 * Item渲染器
	 */
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic>;

	/**
	 * 当前是否为虚拟列表
	 *
	 * 当`layout`是虚拟布局（实现了`IVirtualLayout`，例如`VirtualVerticalLayout`）时自动开启：
	 * 只会为可见区域（以及`virtualBufferCount`行缓冲）创建ItemRenderer，没有被渲染的行区域由布局的占位对象支撑滚动范围，
	 * 滚动过程中会自动复用`itemRendererRecycler`对象池中的ItemRenderer。
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
	 * 默认渲染器的类型图标边长，默认`14`
	 */
	public var iconSize(get, set):Float;

	private var __iconSize:Float = 14;

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
	 * 默认渲染器的文件夹图标颜色，默认`0xDCB67A`（VSCode暗色主题文件夹颜色）
	 */
	public var folderColor(get, set):Int;

	private var __folderColor:Int = 0xDCB67A;

	/**
	 * 默认渲染器的文件图标颜色，默认`0x9BA5AE`
	 */
	public var fileColor(get, set):Int;

	private var __fileColor:Int = 0x9BA5AE;

	/**
	 * 是否把文件夹稳定排在文件前面（各自保持数据源中的原有顺序，不修改数据本身），默认`false`
	 */
	public var foldersFirst(get, set):Bool;

	private var __foldersFirst:Bool = false;

	/**
	 * 是否在非根层级的第一行显示`..`（返回上一级行），默认`true`
	 */
	public var showParentRow(get, set):Bool;

	private var __showParentRow:Bool = true;

	/**
	 * `..`行对应的哨兵节点
	 *
	 * `showParentRow`开启且不在根层级时，它显示在第一行，双击它返回上一级；它不在数据源中，
	 * 也不会派发`ITEM_DOUBLE_CLICKED`，仅作为列表内的导航入口
	 */
	public var parentItem(get, never):TreeItem;

	private var __parentItem:TreeItem = new TreeItem("..");

	/**
	 * 是否允许右键点击来选择
	 */
	public var rightClickSelectEnabled:Bool = true;

	/**
	 * 当前选中的行索引
	 */
	public var selectedIndex(get, set):Int;

	private var __selectedIndex:Int = -1;

	/**
	 * 当前选中的节点（主选中项，最后交互的节点），`null`表示未选中
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
	 * 当前目录的子项平铺成的可见行（不做树形展开，只有一层）
	 */
	private var __rows:Array<TreeRowData> = [];

	/**
	 * 目录或数据发生变化，需要重新平铺
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
	 * 最近一次渲染的行总量与内容尺寸
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
		this.itemRendererRecycler = DisplayObjectRecycler.withClass(FinderItemRenderer);
		// 默认虚拟列表，与Tree一样可以通过layout切换普通模式
		this.layout = new VirtualVerticalLayout(this.__rowHeight);
		this.addEventListener(MouseEvent.CLICK, onRowClick);
		this.addEventListener(MouseEvent.RIGHT_CLICK, onRowClick);
		this.addEventListener(MouseEvent.DOUBLE_CLICK, onRowDoubleClick);
		this.addEventListener(MouseEvent.MOUSE_OVER, onRowMouseOver);
		this.addEventListener(MouseEvent.MOUSE_OUT, onRowMouseOut);
		this.scrollXEnable = false;
	}

	// ============================== 数据与导航 ==============================

	private function get_data():Array<TreeItem> {
		return __data;
	}

	private function set_data(value:Array<TreeItem>):Array<TreeItem> {
		this.__data = value;
		// 新的数据源里已经没有当前目录时，回到根层级
		if (this.__currentItem != null && !this.__isItemAttached(this.__currentItem)) {
			this.__navigateTo(null, false);
		}
		this.refresh();
		return value;
	}

	private function get_currentItem():TreeItem {
		return this.__currentItem;
	}

	private function set_currentItem(value:TreeItem):TreeItem {
		this.__navigateTo(value, false);
		return value;
	}

	/**
	 * 从根节点到当前目录的节点链（包含当前目录，根层级为空数组），可用于自建面包屑导航
	 */
	public var path(get, never):Array<TreeItem>;

	private function get_path():Array<TreeItem> {
		var result:Array<TreeItem> = [];
		var current = this.__currentItem;
		while (current != null) {
			result.unshift(current);
			current = current.parent;
		}
		return result;
	}

	/**
	 * 进入指定的文件夹，成功返回`true`
	 * @param item 目标文件夹节点
	 */
	public function goInto(item:TreeItem):Bool {
		if (item == null || !item.isFolder) {
			return false;
		}
		return this.__navigateTo(item, false);
	}

	/**
	 * 返回上一级目录，并像访达一样自动选中刚退出的文件夹，已在根层级时返回`false`
	 */
	public function goUp():Bool {
		if (this.__currentItem == null) {
			return false;
		}
		return this.__navigateTo(this.__currentItem.parent, true);
	}

	/**
	 * 回到根层级，并自动选中刚退出的文件夹，已在根层级时返回`false`
	 */
	public function goToRoot():Bool {
		if (this.__currentItem == null) {
			return false;
		}
		return this.__navigateTo(null, true);
	}

	/**
	 * 导航到目标目录：清空选中、回到列表顶部并派发`PATH_CHANGED`
	 * @param value 目标目录，`null`表示根层级；非文件夹或不在数据源中时忽略
	 * @param selectExited 是否在新的目录中选中刚退出的文件夹（访达的返回行为）
	 * @return Bool 是否发生了导航
	 */
	private function __navigateTo(value:TreeItem, selectExited:Bool):Bool {
		if (value == this.__currentItem) {
			return false;
		}
		if (value != null && (!value.isFolder || !this.__isItemAttached(value))) {
			return false;
		}
		var exited = this.__currentItem;
		this.__currentItem = value;
		// 原目录内的选中项在新目录中没有意义，切换目录时清空
		this.__selectSingleItem(null);
		this.__rowsDirty = true;
		this.__dataDirty = true;
		var pos = this.getMoveingToData({scrollX: 0, scrollY: 0});
		this.scrollX = pos.scrollX;
		this.scrollY = pos.scrollY;
		this.invalidate();
		this.dispatchEvent(new Event(PATH_CHANGED, false, false, value));
		if (selectExited && exited != null) {
			// 返回上级后自动选中刚退出的文件夹，并让它滚动到可见位置（访达行为）
			this.__selectSingleItem(exited);
			this.scrollToItem(exited, 0);
		}
		return true;
	}

	/**
	 * 数据或目录内容发生变化后手动通知刷新（例如修改了`TreeItem.children`之后）
	 */
	public function refresh():Void {
		// 当前目录被移出数据源时回到根层级（例如它的某个祖先节点被删除）
		if (this.__currentItem != null && !this.__isItemAttached(this.__currentItem)) {
			this.__navigateTo(null, false);
		}
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
		// 只允许选中当前目录内的节点，跨目录的选中没有意义
		if (value != null && this.getRowOfItem(value) < 0) {
			return value;
		}
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

	// ============================== 定位与查询 ==============================

	/**
	 * 滚动到指定节点使其可见，节点不在当前目录时忽略
	 * @param item 目标节点
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToItem(item:TreeItem, duration:Float = 0.2):Void {
		if (item == null) {
			return;
		}
		var row = this.getRowOfItem(item);
		if (row < 0) {
			return;
		}
		this.scrollToIndex(row, duration);
	}

	/**
	 * 滚动到指定的行索引
	 * @param index 行索引
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
	 * @param row 行索引
	 * @return TreeItem 行不存在时返回`null`
	 */
	public function getItemAt(row:Int):TreeItem {
		this.__ensureRows();
		return row >= 0 && row < this.__rows.length ? this.__rows[row].item : null;
	}

	/**
	 * 当前的可见行数量（当前目录的子项数量）
	 */
	public var rowCount(get, never):Int;

	private function get_rowCount():Int {
		this.__ensureRows();
		return this.__rows.length;
	}

	/**
	 * 获得节点所在的行索引，节点不在当前目录中时返回`-1`
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
	 * 获得显示对象对应的节点，用于自定义事件（右键菜单等）中把`event.target`映射为数据
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
		return row >= 0 && row < this.__rows.length ? this.__rows[row].item : null;
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
		// 导航或刷新后的同一帧内，行渲染器还是旧目录的数据（双击文件夹时会先触发DOUBLE_CLICK再触发CLICK），
		// 此时忽略本次点击，等待下一帧渲染完成后再恢复交互
		if (this.__rowsDirty) {
			return;
		}
		this.__ensureRows();
		var renderer = this.__getRendererFromChild(cast e.target);
		if (renderer == null || renderer == this.__spacer) {
			return;
		}
		var row = this.__getRowIndexByRenderer(renderer);
		if (row < 0 || row >= this.__rows.length) {
			return;
		}
		var item = this.__rows[row].item;
		// 右键：只把未选中的节点改为单选，已选中的保留多选（访达行为，配合右键菜单）
		if (e.type == MouseEvent.RIGHT_CLICK) {
			if (!this.__isSelected(item)) {
				this.__selectSingleItem(item);
			}
			return;
		}
		if (e.isCtrlOrCommand) {
			// Ctrl/Cmd+点击：切换单个节点的选中状态，范围选择的锚点移动到该行
			var selected = !this.__isSelected(item);
			this.__setItemSelected(item, selected);
			if (selected) {
				this.__selectedItem = item;
			} else if (this.__selectedItem == item) {
				// 主选中项始终保持在选中集合中，被取消时转移到最近一次选中的节点
				this.__selectedItem = this.__selectedItems.length > 0 ? this.__selectedItems[this.__selectedItems.length - 1] : null;
			}
			this.__selectionAnchor = item;
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
			this.__selectedItem = item;
			this.__selectedIndex = row;
			this.__selectedDirty = true;
			this.invalidate();
			this.dispatchEvent(new Event(Event.CHANGE));
			return;
		}
		// 普通点击：只选中该行，目录导航只由双击触发（访达行为）
		this.__selectSingleItem(item);
	}

	private function onRowDoubleClick(e:MouseEvent):Void {
		// 与onRowClick同理：导航后的同一帧内渲染器尚未重新绑定，忽略本次双击
		if (this.__rowsDirty) {
			return;
		}
		this.__ensureRows();
		var renderer = this.__getRendererFromChild(cast e.target);
		if (renderer == null || renderer == this.__spacer) {
			return;
		}
		var row = this.__getRowIndexByRenderer(renderer);
		if (row < 0 || row >= this.__rows.length) {
			return;
		}
		var item = this.__rows[row].item;
		// 双击`..`行返回上一级，它是导航入口而不是数据节点，不派发ITEM_DOUBLE_CLICKED
		if (item == this.__parentItem) {
			this.goUp();
			return;
		}
		this.dispatchEvent(new Event(ITEM_DOUBLE_CLICKED, false, false, item));
		if (item.isFolder) {
			this.goInto(item);
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
		if (this.__hoverRenderer != null && this.__hoverRenderer is FinderItemRenderer) {
			cast(this.__hoverRenderer, FinderItemRenderer).hovered = false;
		}
		this.__hoverRenderer = renderer;
		if (renderer != null && renderer is FinderItemRenderer) {
			cast(renderer, FinderItemRenderer).hovered = true;
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

	// ============================== 样式 ==============================

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
		// 行宽始终撑满列表
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

	private function get_iconSize():Float {
		return __iconSize;
	}

	private function set_iconSize(value:Float):Float {
		if (__iconSize != value) {
			__iconSize = value;
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

	private function get_folderColor():Int {
		return __folderColor;
	}

	private function set_folderColor(value:Int):Int {
		if (__folderColor != value) {
			__folderColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_fileColor():Int {
		return __fileColor;
	}

	private function set_fileColor(value:Int):Int {
		if (__fileColor != value) {
			__fileColor = value;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_foldersFirst():Bool {
		return __foldersFirst;
	}

	private function set_foldersFirst(value:Bool):Bool {
		if (__foldersFirst != value) {
			__foldersFirst = value;
			this.__rowsDirty = true;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_showParentRow():Bool {
		return __showParentRow;
	}

	private function set_showParentRow(value:Bool):Bool {
		if (__showParentRow != value) {
			__showParentRow = value;
			this.__rowsDirty = true;
			this.__dataDirty = true;
			this.invalidate();
		}
		return value;
	}

	private function get_parentItem():TreeItem {
		return this.__parentItem;
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
	 * 普通模式渲染，为全部行创建ItemRenderer
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
				if (renderer is FinderItemRenderer) {
					cast(renderer, FinderItemRenderer).finder = this;
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
	 * 数据的可见区间、Item的位置与尺寸、占位对象都由虚拟布局负责，`FinderView`只负责ItemRenderer的创建、回收与数据绑定
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

		// 目录变化会整体替换行集合，所有可见Item都需要重新绑定数据与选中状态
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
				if (renderer is FinderItemRenderer) {
					cast(renderer, FinderItemRenderer).finder = this;
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
	 * 把当前目录的子项平铺为可见行（不做树形展开，`depth`恒为`0`）
	 */
	private function __reflatRows():Void {
		this.__rows.resize(0);
		// 非根层级时在第一行显示`..`返回上一级行
		if (this.__showParentRow && this.__currentItem != null) {
			this.__rows.push({item: this.__parentItem, depth: 0});
		}
		var items = this.__currentItem != null ? this.__currentItem.children : this.__data;
		if (items != null) {
			if (this.__foldersFirst) {
				// 文件夹稳定排在文件前面，各自保持数据源中的原有顺序（不修改数据源本身）
				for (item in items) {
					if (item.isFolder) {
						this.__rows.push({item: item, depth: 0});
					}
				}
				for (item in items) {
					if (!item.isFolder) {
						this.__rows.push({item: item, depth: 0});
					}
				}
			} else {
				for (item in items) {
					this.__rows.push({item: item, depth: 0});
				}
			}
		}
		this.__rowsDirty = false;
		// 已经不在数据源中的选中项不再保持选中
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

	/**
	 * 确保可见行与目录内容同步，查询接口在平铺之前调用
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
	 * 清理所有子对象，全部回收到ItemRenderer的对象池
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
