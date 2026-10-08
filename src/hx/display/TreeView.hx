package hx.display;

import hx.events.Event;
import hx.events.MouseEvent;
import hx.layout.VirtualVerticalLayout;
import haxe.ds.ObjectMap;

/**
 * 节点数据结构，使用匿名对象即可直接使用：
 *
 * ```haxe
 * tree.data = new ArrayCollection([
 *     {name: "src", expanded: true, children: [
 *         {name: "Main.hx"},
 *         {name: "assets", children: [{name: "logo.png"}]},
 *     ]},
 *     {name: "project.xml"},
 * ]);
 * ```
 *
 * 节点也可以是任意自定义类型，通过`TreeView`的`labelFunction`、`childrenFunction`等解析函数适配。
 */
typedef TreeNodeData = {
	/**
	 * 显示名称
	 */
	var name:String;

	/**
	 * 子节点数组，`null`或空数组表示叶子节点
	 */
	var ?children:Array<Dynamic>;

	/**
	 * 初始是否展开，默认`false`，运行时的展开状态由`TreeView`维护
	 */
	var ?expanded:Bool;

	/**
	 * 图标位图，默认`null`表示不显示图标
	 */
	var ?icon:BitmapData;

	/**
	 * 用户自定义数据载荷
	 */
	var ?data:Dynamic;
}

/**
 * 树形列表视图，类似VSCode的资源管理器
 *
 * 默认使用`VirtualVerticalLayout`虚拟布局：内部把数据按展开状态扁平化为可见行，
 * 只为可见区域（以及`virtualBufferCount`条缓冲）创建`TreeItemRenderer`，
 * 未展开的分支不会被遍历，因此可以承载成千上万节点。展开状态由`TreeView`维护并优先于节点的`expanded`字段。
 *
 * 交互约定：
 * - 单击行选中，派发`Event.CHANGE`；单击展开箭头只切换展开状态，不改变选中
 * - 双击有子级的行切换展开状态；右键默认选中，可用于呼出上下文菜单
 * - `ITEM_TOGGLE`事件在节点展开/收起时派发，`data`为该节点
 */
@:keep
class TreeView extends BaseVirtualList implements IDataProider<ArrayCollection> {
	/**
	 * 节点展开/收起时派发的事件类型，`data`为对应的节点
	 */
	public inline static var ITEM_TOGGLE:String = "itemToggle";

	/**
	 * 根节点集合
	 */
	public var data(get, set):ArrayCollection;

	private var __roots:ArrayCollection = null;

	/**
	 * 解析节点的显示名称，默认读取节点的`name`字段
	 */
	public var labelFunction:Dynamic->String = null;

	/**
	 * 解析节点的子节点数组，默认读取节点的`children`字段
	 */
	public var childrenFunction:Dynamic->Array<Dynamic> = null;

	/**
	 * 解析节点是否拥有子级，设置后未展开的节点不会访问其子节点，可用于按需加载数据的惰性树
	 */
	public var hasChildrenFunction:Dynamic->Bool = null;

	/**
	 * 解析节点的初始展开状态，默认读取节点的`expanded`字段
	 */
	public var expandedFunction:Dynamic->Bool = null;

	/**
	 * 解析节点的图标位图，默认读取节点的`icon`字段
	 */
	public var iconFunction:Dynamic->BitmapData = null;

	/**
	 * 行高，需要与`VirtualVerticalLayout`的`itemSize`保持一致，默认`22`
	 */
	public var rowHeight(default, set):Float = 22;

	/**
	 * 每一层级的缩进尺寸，默认`8`
	 */
	public var indentSize(default, set):Float = 8;

	/**
	 * 选中高亮颜色，同步给可见的`TreeItemRenderer`
	 */
	public var selectionColor(default, set):Int = 0x04395e;

	/**
	 * 悬停高亮颜色，同步给可见的`TreeItemRenderer`
	 */
	public var hoverColor(default, set):Int = 0x2a2d2e;

	/**
	 * 列表是否允许右键点击来选择，默认`true`
	 */
	public var rightClickSelectEnabled:Bool = true;

	/**
	 * 当前选中的行号（扁平化后的可见行索引），`-1`表示未选中
	 */
	public var selectedIndex(get, set):Int;

	private var __selectedIndex:Int = -1;

	/**
	 * 选中的节点，收起的分支中的节点不可见，需要先`scrollToItem()`展开定位后再选中
	 */
	public var selectedItem(get, set):Dynamic;

	private var __selectedNode:Dynamic = null;

	/**
	 * 展开状态的扁平行列表，只在结构变化时重建
	 */
	private var __flatRows:Array<TreeRow> = [];

	/**
	 * 节点与扁平行号的映射（以节点对象为键）
	 */
	private var __rowOfNode:ObjectMap<Dynamic, Int> = new ObjectMap();

	/**
	 * 节点与父节点的映射，用于`scrollToItem()`展开祖先链（以节点对象为键）
	 */
	private var __parentOfNode:ObjectMap<Dynamic, Dynamic> = new ObjectMap();

	/**
	 * 运行时的展开状态，节点对象为键，优先于节点的`expanded`字段
	 */
	private var __expandedStates:ObjectMap<Dynamic, Bool> = new ObjectMap();

	/**
	 * 扁平行列表是否需要重建
	 */
	private var __flatDirty:Bool = true;

	override function onInit() {
		super.onInit();
		this.itemRendererRecycler = DisplayObjectRecycler.withClass(TreeItemRenderer);
		var layout = new VirtualVerticalLayout(this.rowHeight);
		layout.horizontalFill = true;
		this.layout = layout;
		this.addEventListener(MouseEvent.CLICK, __onTreeItemClick);
		this.addEventListener(MouseEvent.RIGHT_CLICK, __onTreeItemClick);
		this.addEventListener(MouseEvent.DOUBLE_CLICK, __onTreeItemDoubleClick);
	}

	// ============================== 数据 ==============================

	private function set_data(value:ArrayCollection):ArrayCollection {
		if (this.__roots != value) {
			if (this.__roots != null) {
				this.__roots.removeEventListener(Event.ADDED, __onCollectionChanged);
				this.__roots.removeEventListener(Event.REMOVED, __onCollectionChanged);
			}
			this.__roots = value;
			if (this.__roots != null) {
				this.__roots.addEventListener(Event.ADDED, __onCollectionChanged);
				this.__roots.addEventListener(Event.REMOVED, __onCollectionChanged);
			}
			// 数据整体被替换后，父节点缓存随之失效
			this.__parentOfNode.clear();
		}
		this.__structureChanged();
		return value;
	}

	private function get_data():ArrayCollection {
		return this.__roots;
	}

	/**
	 * 顶层节点集合的增删事件
	 */
	private function __onCollectionChanged(e:Event):Void {
		this.__structureChanged();
	}

	override public function updateAllData():Void {
		super.updateAllData();
		this.__flatDirty = true;
	}

	/**
	 * 结构发生变化（数据替换、节点增删、展开/收起），需要重新扁平化并刷新可见行
	 */
	private function __structureChanged():Void {
		this.__flatDirty = true;
		this.__dataDirty = true;
		this.invalidate();
	}

	// ============================== 外观 ==============================

	private function set_rowHeight(value:Float):Float {
		if (this.rowHeight == value) {
			return value;
		}
		this.rowHeight = value;
		if (this.layout is VirtualVerticalLayout) {
			cast(this.layout, VirtualVerticalLayout).itemSize = value;
		}
		this.__dataDirty = true;
		return value;
	}

	private function set_indentSize(value:Float):Float {
		if (this.indentSize == value) {
			return value;
		}
		this.indentSize = value;
		this.__dataDirty = true;
		return value;
	}

	private function set_selectionColor(value:Int):Int {
		if (this.selectionColor == value) {
			return value;
		}
		this.selectionColor = value;
		this.__dataDirty = true;
		return value;
	}

	private function set_hoverColor(value:Int):Int {
		if (this.hoverColor == value) {
			return value;
		}
		this.hoverColor = value;
		this.__dataDirty = true;
		return value;
	}

	// ============================== 展开/收起 ==============================

	/**
	 * 节点当前是否处于展开状态，叶子节点恒为`false`
	 */
	public function isExpanded(node:Dynamic):Bool {
		if (node == null) {
			return false;
		}
		if (this.__expandedStates.exists(node)) {
			return this.__expandedStates.get(node);
		}
		return this.__getInitialExpanded(node);
	}

	/**
	 * 展开节点
	 * @param node 目标节点
	 * @param recursive 是否递归展开全部子孙节点
	 */
	public function expandItem(node:Dynamic, recursive:Bool = false):Void {
		this.__applyExpandedToNode(node, true, recursive);
	}

	/**
	 * 收起节点
	 * @param node 目标节点
	 * @param recursive 是否递归收起全部子孙节点
	 */
	public function collapseItem(node:Dynamic, recursive:Bool = false):Void {
		this.__applyExpandedToNode(node, false, recursive);
	}

	/**
	 * 切换节点的展开状态
	 */
	public function toggleItem(node:Dynamic):Void {
		if (node == null) {
			return;
		}
		if (this.isExpanded(node)) {
			this.collapseItem(node);
		} else {
			this.expandItem(node);
		}
	}

	/**
	 * 展开全部节点，会遍历整棵树（包括未展开的分支）
	 */
	public function expandAll():Void {
		this.__applyExpandedToAll(true);
	}

	/**
	 * 收起全部节点
	 */
	public function collapseAll():Void {
		this.__applyExpandedToAll(false);
	}

	private function __applyExpandedToNode(node:Dynamic, expanded:Bool, recursive:Bool):Void {
		if (node == null) {
			return;
		}
		if (!this.__applyExpanded(node, expanded, recursive)) {
			return;
		}
		this.__structureChanged();
		this.dispatchEvent(new Event(ITEM_TOGGLE, false, false, node));
	}

	private function __applyExpandedToAll(expanded:Bool):Void {
		if (this.__roots == null) {
			return;
		}
		var changed = false;
		for (root in this.__roots.source) {
			if (root != null && this.__applyExpanded(root, expanded, true)) {
				changed = true;
			}
		}
		if (changed) {
			this.__structureChanged();
		}
	}

	/**
	 * 写入节点（及递归子孙）的展开状态
	 * @return 状态是否发生了变化
	 */
	private function __applyExpanded(node:Dynamic, expanded:Bool, recursive:Bool):Bool {
		var changed = false;
		if (this.isExpanded(node) != expanded) {
			this.__expandedStates.set(node, expanded);
			changed = true;
		}
		if (recursive) {
			var children = this.__getChildren(node);
			if (children != null) {
				for (child in children) {
					if (child != null && this.__applyExpanded(child, expanded, true)) {
						changed = true;
					}
				}
			}
		}
		return changed;
	}

	// ============================== 选择 ==============================

	private function get_selectedIndex():Int {
		return this.__selectedIndex;
	}

	private function set_selectedIndex(value:Int):Int {
		if (this.__selectedIndex == value) {
			return value;
		}
		this.__ensureFlat();
		this.__selectedIndex = value;
		this.__selectedNode = value >= 0 && value < this.__flatRows.length ? this.__flatRows[value].node : null;
		this.__selectionDirty = true;
		this.dispatchEvent(new Event(Event.CHANGE));
		return value;
	}

	private function get_selectedItem():Dynamic {
		this.__ensureFlat();
		if (this.__selectedIndex >= 0 && this.__selectedIndex < this.__flatRows.length) {
			return this.__flatRows[this.__selectedIndex].node;
		}
		return null;
	}

	private function set_selectedItem(value:Dynamic):Dynamic {
		this.__ensureFlat();
		var index = value != null ? this.__rowOfNode.get(value) : null;
		if (index != null) {
			this.selectedIndex = index;
		}
		return value;
	}

	/**
	 * 扁平化后同步选中行号：选中节点被移除或被收起后，行号跟随节点调整
	 */
	private function __syncSelectedIndex():Void {
		var index = this.__selectedNode != null ? this.__rowOfNode.get(this.__selectedNode) : null;
		var newIndex = index != null ? index : -1;
		if (newIndex != this.__selectedIndex) {
			this.__selectedIndex = newIndex;
			this.__selectionDirty = true;
		}
	}

	// ============================== 定位 ==============================

	/**
	 * 滚动到指定节点，节点位于收起的分支内时会先展开其祖先链
	 * @param node 目标节点
	 * @param duration 滚动时间，`0`表示立即定位
	 */
	public function scrollToItem(node:Dynamic, duration:Float = 0.2):Void {
		if (node == null || this.__roots == null) {
			return;
		}
		var changed = false;
		if (!this.__rowOfNode.exists(node)) {
			// 节点不可见：自根向下展开祖先链
			var path = this.__findPath(node);
			if (path == null) {
				return;
			}
			for (i in 0...path.length - 1) {
				var ancestor = path[i];
				if (!this.isExpanded(ancestor)) {
					this.__expandedStates.set(ancestor, true);
					changed = true;
				}
			}
		}
		if (changed) {
			this.__structureChanged();
		}
		this.__ensureFlat();
		var index = this.__rowOfNode.get(node);
		if (index != null) {
			this.scrollToIndex(index, duration);
		}
	}

	/**
	 * 深度优先搜索节点所在的祖先链（从根节点到目标节点，含目标节点），找不到时返回`null`
	 */
	private function __findPath(node:Dynamic):Array<Dynamic> {
		if (this.__roots == null) {
			return null;
		}
		for (root in this.__roots.source) {
			var path = this.__findPathWalk(root, node);
			if (path != null) {
				return path;
			}
		}
		return null;
	}

	private function __findPathWalk(current:Dynamic, target:Dynamic):Array<Dynamic> {
		if (current == null) {
			return null;
		}
		if (current == target) {
			return [current];
		}
		var children = this.__getChildren(current);
		if (children != null) {
			for (child in children) {
				var path = this.__findPathWalk(child, target);
				if (path != null) {
					path.unshift(current);
					return path;
				}
			}
		}
		return null;
	}

	// ============================== 扁平化 ==============================

	/**
	 * 按需重建扁平行列表，只走已展开的分支
	 */
	private function __ensureFlat():Void {
		if (!this.__flatDirty) {
			return;
		}
		this.__flatRows.resize(0);
		this.__rowOfNode.clear();
		if (this.__roots != null) {
			this.__walk(this.__roots.source, 0, null);
		}
		this.__flatDirty = false;
		this.__syncSelectedIndex();
	}

	private function __walk(nodes:Array<Dynamic>, depth:Int, parentNode:Dynamic):Void {
		for (node in nodes) {
			if (node == null) {
				continue;
			}
			if (parentNode != null) {
				this.__parentOfNode.set(node, parentNode);
			}
			var expanded = this.isExpanded(node);
			var children:Array<Dynamic> = null;
			var hasChildren:Bool;
			if (this.hasChildrenFunction != null) {
				// 惰性模式：未展开的节点不访问其子节点
				hasChildren = this.hasChildrenFunction(node);
				if (hasChildren && expanded) {
					children = this.__getChildren(node);
				}
			} else {
				children = this.__getChildren(node);
				hasChildren = children != null && children.length > 0;
			}
			var row = new TreeRow();
			row.node = node;
			row.depth = depth;
			row.hasChildren = hasChildren;
			row.expanded = expanded;
			this.__rowOfNode.set(node, this.__flatRows.length);
			this.__flatRows.push(row);
			if (hasChildren && expanded && children != null && children.length > 0) {
				this.__walk(children, depth + 1, node);
			}
		}
	}

	// ============================== 节点解析 ==============================

	private function __getChildren(node:Dynamic):Array<Dynamic> {
		if (node == null) {
			return null;
		}
		if (this.childrenFunction != null) {
			return this.childrenFunction(node);
		}
		return Reflect.field(node, "children");
	}

	private function __getInitialExpanded(node:Dynamic):Bool {
		if (this.expandedFunction != null) {
			return this.expandedFunction(node);
		}
		return Reflect.field(node, "expanded") == true;
	}

	private function __getNodeName(node:Dynamic):String {
		if (node == null) {
			return "";
		}
		if (this.labelFunction != null) {
			return this.labelFunction(node);
		}
		var name = Reflect.field(node, "name");
		return name != null ? Std.string(name) : "";
	}

	private function __getNodeIcon(node:Dynamic):BitmapData {
		if (node == null) {
			return null;
		}
		if (this.iconFunction != null) {
			return this.iconFunction(node);
		}
		var icon = Reflect.field(node, "icon");
		return icon is BitmapData ? cast icon : null;
	}

	// ============================== 交互 ==============================

	private function __onTreeItemClick(e:MouseEvent):Void {
		if (e.type == MouseEvent.RIGHT_CLICK && !this.rightClickSelectEnabled) {
			return;
		}
		var renderer = this.__getRendererByChild(e.target);
		var index = this.__getRendererIndex(renderer);
		if (index < 0) {
			return;
		}
		this.__ensureFlat();
		if (index >= this.__flatRows.length) {
			return;
		}
		// 点击展开箭头区域：只切换展开状态，不改变选中
		if (renderer is TreeItemRenderer && cast(renderer, TreeItemRenderer).hitDisclosure(e.stageX, e.stageY)) {
			this.toggleItem(this.__flatRows[index].node);
			return;
		}
		this.selectedIndex = index;
	}

	private function __onTreeItemDoubleClick(e:MouseEvent):Void {
		var renderer = this.__getRendererByChild(e.target);
		var index = this.__getRendererIndex(renderer);
		if (index < 0) {
			return;
		}
		this.__ensureFlat();
		if (index >= this.__flatRows.length) {
			return;
		}
		// 箭头区域的双击由单击逻辑处理，避免重复切换
		if (renderer is TreeItemRenderer && cast(renderer, TreeItemRenderer).hitDisclosure(e.stageX, e.stageY)) {
			return;
		}
		var row = this.__flatRows[index];
		if (row.hasChildren) {
			this.toggleItem(row.node);
		}
	}

	// ============================== 虚拟列表的钩子 ==============================

	override function __getVirtualTotal():Int {
		this.__ensureFlat();
		return this.__flatRows.length;
	}

	override function __bindVirtualRendererData(renderer:DisplayObject, index:Int):Void {
		this.__ensureFlat();
		if (index >= this.__flatRows.length) {
			return;
		}
		var row = this.__flatRows[index];
		if (renderer is TreeItemRenderer) {
			var itemRenderer:TreeItemRenderer = cast renderer;
			itemRenderer.rowHeight = this.rowHeight;
			itemRenderer.indentSize = this.indentSize;
			itemRenderer.selectionColor = this.selectionColor;
			itemRenderer.hoverColor = this.hoverColor;
			itemRenderer.treeNodeDepth = row.depth;
			itemRenderer.treeNodeHasChildren = row.hasChildren;
			itemRenderer.treeNodeExpanded = row.expanded;
			itemRenderer.treeNodeName = this.__getNodeName(row.node);
			itemRenderer.treeNodeIcon = this.__getNodeIcon(row.node);
		}
		if (renderer is IDataProider) {
			var proider:IDataProider<Dynamic> = cast renderer;
			proider.data = row.node;
		}
	}

	override function __bindVirtualRendererSelected(renderer:DisplayObject, index:Int):Void {
		if (renderer is ISelectProider) {
			var proider:ISelectProider = cast renderer;
			proider.selected = index == this.__selectedIndex;
		}
	}

	override function __updateNonVirtual():Void {
		if (!this.__dataDirty) {
			return;
		}
		this.__ensureFlat();
		this.__clearChildren();
		for (i in 0...this.__flatRows.length) {
			var renderer:DisplayObject = this.itemRendererRecycler.create();
			this.addChild(renderer);
			this.__bindVirtualRendererData(renderer, i);
			this.__bindVirtualRendererSelected(renderer, i);
		}
		this.updateLayout();
		this.__dataDirty = false;
	}
}

/**
 * 展开状态的扁平行，`TreeView`内部使用
 */
private class TreeRow {
	/**
	 * 行对应的节点
	 */
	public var node:Dynamic;

	/**
	 * 节点的层级深度，根节点为`0`
	 */
	public var depth:Int = 0;

	/**
	 * 节点是否拥有子级
	 */
	public var hasChildren:Bool = false;

	/**
	 * 节点是否处于展开状态
	 */
	public var expanded:Bool = false;

	public function new() {}
}
