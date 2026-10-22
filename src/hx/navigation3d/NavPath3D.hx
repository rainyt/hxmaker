package hx.navigation3d;

import hx.geom.Vector3D;

/** 一次搜索的快照；后续修改图不会改写该结果。 */
class NavPath3D {
	/** 搜索状态，只有 FOUND 携带路径。 */
	public var status(default, null):NavPathStatus3D;

	/** 搜索时的图版本，供跟随器判断是否需要重规划。 */
	public var revision(default, null):Int;

	/** 路径总成本；失败时为正无穷。 */
	public var cost(default, null):Float;

	/** 本次实际展开的节点数。 */
	public var visitedCount(default, null):Int;

	/** 路径节点编号副本，包含起点和终点。 */
	public var nodeIds(get, never):Array<Int>;

	/** 世界脚底路点的深拷贝，包含起点和终点。 */
	public var points(get, never):Array<Vector3D>;

	private var ids:Array<Int>;
	private var positions:Array<Vector3D>;

	@:allow(hx.navigation3d.NavGraph3D)
	private function new(status:NavPathStatus3D, revision:Int, visited:Int, cost:Float, nodes:Array<NavNode3D>) {
		this.status = status;
		this.revision = revision;
		visitedCount = visited;
		this.cost = cost;
		ids = [for (node in nodes) node.id];
		positions = [for (node in nodes) node.position];
	}

	private function get_nodeIds():Array<Int> {
		return ids.copy();
	}

	private function get_points():Array<Vector3D> {
		return [for (point in positions) point.clone()];
	}
}
