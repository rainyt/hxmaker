package hx.display;

/**
 * 传递给`TreeItemRenderer`的行数据，由`Tree`在扁平化可见节点时生成
 */
typedef TreeRowData = {
	/**
	 * 行对应的树节点
	 */
	var item:TreeItem;

	/**
	 * 节点的层级深度，根节点为`0`，子节点逐级递增
	 */
	var depth:Int;
}
