package hx.navigation3d;

/** 搜索结果；参数错误抛异常，合法但不可达的请求返回状态。 */
enum abstract NavPathStatus3D(String) to String {
	/** 找到最短路。 */
	var FOUND = "found";

	/** 起点失效、被禁用或不属于图。 */
	var INVALID_START = "invalidStart";

	/** 目标失效、被禁用或不属于图。 */
	var INVALID_GOAL = "invalidGoal";

	/** 开放集合耗尽，目标不可达。 */
	var UNREACHABLE = "unreachable";

	/** 本次节点展开预算用尽，尚不能确定是否可达。 */
	var SEARCH_LIMIT = "searchLimit";
}
