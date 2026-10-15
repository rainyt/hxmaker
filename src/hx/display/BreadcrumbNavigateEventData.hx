package hx.display;

/** NAVIGATE 的数据；index 始终对应完整路径，item.data 保留原始业务引用。 */
typedef BreadcrumbNavigateEventData = {
	var index:Int;
	var item:BreadcrumbItem;
}
