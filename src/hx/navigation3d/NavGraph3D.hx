package hx.navigation3d;

import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 显式路点图与同步 A* 搜索；项目负责保证每条边适合角色尺寸、坡度和跨步能力。 */
class NavGraph3D {
	/** 图是否已经销毁。 */
	public var isDisposed(default, null):Bool = false;

	/** 拓扑、位置或通行状态发生变更时递增。 */
	public var revision(default, null):Int = 0;

	/** 当前节点列表副本；节点引用由图持有。 */
	public var nodes(get, never):Array<NavNode3D>;

	/** 当前有向边列表副本。 */
	public var edges(get, never):Array<NavEdge3D>;

	private var entries:Array<NavNode3D> = [];
	private var links:Array<NavEdge3D> = [];
	private var outgoing:Map<Int, Array<NavEdge3D>> = [];
	private var nextId:Int = 0;

	/** 创建空图，不注册帧回调。 */
	public function new() {}

	private function get_nodes():Array<NavNode3D> {
		return entries.copy();
	}

	private function get_edges():Array<NavEdge3D> {
		return links.copy();
	}

	private function alive():Void {
		if (isDisposed)
			throw "导航图已经销毁";
	}

	@:allow(hx.navigation3d.NavNode3D)
	@:allow(hx.navigation3d.NavEdge3D)
	private function touch():Void {
		alive();
		revision++;
	}

	private static function vector(value:Vector3D):Void {
		if (value == null || !Math3D.finite(value.x) || !Math3D.finite(value.y) || !Math3D.finite(value.z))
			throw "导航位置必须是有限三维坐标";
	}

	@:allow(hx.navigation3d.NavEdge3D)
	private static function checkCost(value:Null<Float>):Void {
		if (value != null && (!Math3D.finite(value) || value < 0))
			throw "导航成本必须为非负有限数值";
	}

	private function owns(value:NavNode3D):Bool {
		return value != null && value.graph == this;
	}

	private function requireNode(value:NavNode3D):Void {
		alive();
		if (!owns(value))
			throw "导航节点不属于当前图";
	}

	/** 添加世界脚底路点；输入向量会复制。 */
	public function addNode(position:Vector3D, name:String = null):NavNode3D {
		alive();
		vector(position);
		var node = new NavNode3D(this, nextId++, position, name);
		entries.push(node);
		outgoing.set(node.id, []);
		touch();
		return node;
	}

	/** 修改路点位置并使已有路径过期。 */
	public function moveNode(node:NavNode3D, position:Vector3D):Void {
		requireNode(node);
		vector(position);
		node.move(position);
		touch();
	}

	/** 移除路点及所有关联边，不复用编号。重复移除无操作。 */
	public function removeNode(node:NavNode3D):Void {
		alive();
		if (!owns(node))
			return;
		for (edge in links.copy())
			if (edge.from == node || edge.to == node)
				disconnect(edge);
		entries.remove(node);
		outgoing.remove(node.id);
		node.detach();
		touch();
	}

	/** 创建一条有向边；已有同向边时返回原边且不修改其成本或开关。 */
	public function connect(from:NavNode3D, to:NavNode3D, cost:Null<Float> = null):NavEdge3D {
		requireNode(from);
		requireNode(to);
		checkCost(cost);
		for (edge in outgoing.get(from.id))
			if (edge.to == to)
				return edge;
		var edge = new NavEdge3D(this, from, to, cost);
		links.push(edge);
		outgoing.get(from.id).push(edge);
		touch();
		return edge;
	}

	/** 创建双向通路，返回正向、反向两条边；两侧开关需分别设置。 */
	public function connectBoth(a:NavNode3D, b:NavNode3D, cost:Null<Float> = null):Array<NavEdge3D> {
		return [connect(a, b, cost), connect(b, a, cost)];
	}

	/** 断开一条有向边；重复断开无操作。 */
	public function disconnect(edge:NavEdge3D):Void {
		alive();
		if (edge == null || edge.graph != this)
			return;
		links.remove(edge);
		outgoing.get(edge.from.id).remove(edge);
		edge.detach();
		touch();
	}

	/** 按三维距离查找启用节点，可用过滤器排除隔墙或不同楼层的接入点；无候选返回 null。 */
	public function nearest(position:Vector3D, maxDistance:Float, filter:NavNode3D->Bool = null):NavNode3D {
		alive();
		vector(position);
		if (!Math3D.finite(maxDistance) || maxDistance < 0)
			throw "接入距离必须非负有限";
		var best:NavNode3D = null, distance = maxDistance;
		for (node in entries)
			if (node.enabled) {
				var candidate = node.position.subtract(position).length;
				if (candidate <= distance && (filter == null || filter(node)) && (best == null || candidate < distance)) {
					best = node;
					distance = candidate;
				}
			}
		return best;
	}

	/** 同步搜索最短路；预算限制展开数。低成本边自动降低启发式，零成本边可退化为 Dijkstra。 */
	public function findPath(start:NavNode3D, goal:NavNode3D, maxVisited:Int = 4096):NavPath3D {
		alive();
		if (maxVisited < 1)
			throw "搜索预算必须为正整数";
		if (!owns(start) || !start.enabled)
			return result(NavPathStatus3D.INVALID_START, 0);
		if (!owns(goal) || !goal.enabled)
			return result(NavPathStatus3D.INVALID_GOAL, 0);
		var scale = 1.;
		for (edge in links)
			if (edge.enabled && edge.from.enabled && edge.to.enabled) {
				var distance = edge.from.position.subtract(edge.to.position).length,
					weight = edge.getCost();
				if (!Math3D.finite(distance) || !Math3D.finite(weight))
					throw "导航图的距离或成本超出有限范围";
				if (distance > 0)
					scale = Math.min(scale, weight / distance);
			}
		var heap = new NavHeap3D(), scores:Map<Int, Float> = [], parents:Map<Int, NavNode3D> = [], visited = 0;
		scores.set(start.id, 0);
		heap.push({node: start, g: 0, f: start.position.subtract(goal.position).length * scale});
		while (heap.length > 0) {
			var item = heap.pop(), node = item.node;
			if (item.g != scores.get(node.id))
				continue;
			if (visited >= maxVisited)
				return result(NavPathStatus3D.SEARCH_LIMIT, visited);
			visited++;
			if (node == goal) {
				var path = [goal], current = goal;
				while (current != start) {
					current = parents.get(current.id);
					path.push(current);
				}
				path.reverse();
				return new NavPath3D(NavPathStatus3D.FOUND, revision, visited, item.g, path);
			}
			for (edge in outgoing.get(node.id))
				if (edge.enabled && edge.to.enabled) {
					var score = item.g + edge.getCost();
					if (!Math3D.finite(score))
						throw "导航累计成本超出有限范围";
					if (!scores.exists(edge.to.id) || score < scores.get(edge.to.id)) {
						scores.set(edge.to.id, score);
						parents.set(edge.to.id, node);
						heap.push({node: edge.to, g: score, f: score + edge.to.position.subtract(goal.position).length * scale});
					}
				}
		}
		return result(NavPathStatus3D.UNREACHABLE, visited);
	}

	private function result(status:NavPathStatus3D, visited:Int):NavPath3D {
		return new NavPath3D(status, revision, visited, Math.POSITIVE_INFINITY, []);
	}

	/** 清空并解除节点、连接的归属；保持图可复用。 */
	public function clear():Void {
		alive();
		for (edge in links)
			edge.detach();
		for (node in entries)
			node.detach();
		entries = [];
		links = [];
		outgoing = [];
		touch();
	}

	/** 幂等销毁图；不影响角色、碰撞世界或模型。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		clear();
		isDisposed = true;
	}
}

private typedef NavQueueItem3D = {var node:NavNode3D; var g:Float; var f:Float;}

/** 二叉最小堆，等成本时按节点编号稳定排序。 */
private class NavHeap3D {
	/** 当前队列条目数量，包含尚未弹出的过期候选。 */
	public var length(get, never):Int;

	private var items:Array<NavQueueItem3D> = [];

	/** 创建空搜索队列。 */
	public function new() {}

	private function get_length():Int {
		return items.length;
	}

	private function before(a:NavQueueItem3D, b:NavQueueItem3D):Bool {
		return a.f < b.f || a.f == b.f && a.node.id < b.node.id;
	}

	/** 按估计成本和节点编号压入搜索候选。 */
	public function push(item:NavQueueItem3D):Void {
		var index = items.length;
		items.push(item);
		while (index > 0) {
			var parent = (index - 1) >> 1;
			if (!before(item, items[parent]))
				break;
			items[index] = items[parent];
			index = parent;
		}
		items[index] = item;
	}

	/** 弹出当前最优候选；调用前须确认队列非空。 */
	public function pop():NavQueueItem3D {
		var first = items[0], last = items.pop();
		if (items.length > 0) {
			var index = 0;
			while (index * 2 + 1 < items.length) {
				var child = index * 2 + 1;
				if (child + 1 < items.length && before(items[child + 1], items[child]))
					child++;
				if (!before(items[child], last))
					break;
				items[index] = items[child];
				index = child;
			}
			items[index] = last;
		}
		return first;
	}
}
