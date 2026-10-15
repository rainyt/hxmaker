package hx.display;

/** 从根到当前位置的单个导航项；data 由调用方持有，组件不修改或销毁它。 */
typedef BreadcrumbItem = {
	var label:String;
	var data:Dynamic;
}
