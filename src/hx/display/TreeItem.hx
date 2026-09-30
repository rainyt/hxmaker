package hx.display;

/**
 * 树数据节点
 *
 * `children`为`null`或空数组的节点为叶子节点，文件夹节点通过`expanded`声明初始展开状态。
 * 直接修改`children`后需要调用`Tree.refresh()`通知树刷新。
 */
@:keep
class TreeItem {
	/**
	 * 节点显示文本
	 */
	public var label:String;

	/**
	 * 用户自定义数据
	 */
	public var data:Dynamic;

	/**
	 * 子节点列表，`null`表示叶子节点
	 */
	public var children:Array<TreeItem> = null;

	/**
	 * 是否处于展开状态，只有文件夹节点有效
	 */
	public var expanded:Bool = false;

	/**
	 * 父节点，根节点为`null`
	 */
	public var parent(default, null):TreeItem = null;

	/**
	 * 是否为文件夹节点（存在子节点）
	 */
	public var isFolder(get, never):Bool;

	public function new(label:String = null, ?children:Array<TreeItem>, expanded:Bool = false) {
		this.label = label;
		this.expanded = expanded;
		if (children != null) {
			for (child in children) {
				this.addChild(child);
			}
		}
	}

	private function get_isFolder():Bool {
		return this.children != null && this.children.length > 0;
	}

	/**
	 * 添加子节点
	 * @param item 子节点，如果它已经挂在其它节点上会先从原节点移除
	 * @return TreeItem 返回添加的子节点
	 */
	public function addChild(item:TreeItem):TreeItem {
		if (item == this) {
			return item;
		}
		if (item.parent != null) {
			item.parent.removeChild(item);
		}
		if (this.children == null) {
			this.children = [];
		}
		item.parent = this;
		this.children.push(item);
		return item;
	}

	/**
	 * 移除子节点
	 * @param item 要移除的子节点
	 * @return TreeItem 移除成功返回该节点，不存在时返回`null`
	 */
	public function removeChild(item:TreeItem):TreeItem {
		if (this.children != null && this.children.remove(item)) {
			item.parent = null;
			return item;
		}
		return null;
	}
}

