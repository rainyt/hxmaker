import hx.navigation3d.NavGraph3D;
import hx.navigation3d.NavPathStatus3D;
import hx.geom.Vector3D;

/** 不需要 GPU 的图搜索断言，包含与独立最短路算法的交叉核对。 */
class NavigationGraphChecks {
	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
	}

	static function main():Void {
		var graph = new NavGraph3D();
		var a = graph.addNode(new Vector3D()),
			b = graph.addNode(new Vector3D(1, 0, 0)),
			c = graph.addNode(new Vector3D(2, 0, 0));
		var direct = graph.connect(a, c, 8);
		graph.connect(a, b, 0);
		graph.connect(b, c, 0);
		graph.connect(b, a, 0);
		var path = graph.findPath(a, c);
		check(path.status == NavPathStatus3D.FOUND && path.cost == 0 && path.nodeIds.length == 3, "零成本连接或循环错误");
		check(graph.findPath(c, a).status == NavPathStatus3D.UNREACHABLE, "单向边被反向使用");
		check(graph.findPath(a, a).cost == 0, "同起终点错误");
		check(graph.findPath(a, c, 1).status == NavPathStatus3D.SEARCH_LIMIT, "展开预算失效");
		b.enabled = false;
		check(graph.findPath(a, c).cost == 8, "禁用节点仍参与搜索");
		direct.enabled = false;
		check(graph.findPath(a, c).status == NavPathStatus3D.UNREACHABLE, "禁用边仍通行");
		var snapshot = path.points;
		snapshot[0].x = 100;
		check(path.points[0].x == 0, "路径位置可被外部修改");
		var copy = a.position;
		copy.x = 99;
		check(a.position.x == 0, "节点位置泄漏引用");
		graph.moveNode(a, new Vector3D(3, 0, 0));
		check(path.points[0].x == 0 && path.revision != graph.revision, "旧路径未保持快照");
		graph.removeNode(b);
		check(b.graph == null && graph.edges.length == 1, "删除节点未删除关联边");
		check(graph.findPath(b, c).status == NavPathStatus3D.INVALID_START, "失效起点未报告");
		check(graph.findPath(c, b).status == NavPathStatus3D.INVALID_GOAL, "失效终点未报告");
		var foreign = new NavGraph3D().addNode(new Vector3D());
		var rejected = false;
		try
			graph.connect(a, foreign)
		catch (_:Dynamic)
			rejected = true;
		check(rejected, "跨图连接被接受");
		graph.dispose();
		graph.dispose();
		check(a.graph == null && direct.graph == null, "图销毁未解除归属");
		// 随机图与 Floyd-Warshall 对照，覆盖启发式缩放、堆更新和不同最短路线。
		var seed = 73013;
		function random():Float {
			seed = (seed * 1664525 + 1013904223);
			return (seed >>> 1) / 2147483648.;
		}
		for (trial in 0...12) {
			var g = new NavGraph3D(), nodes = [
				for (i in 0...18) g.addNode(new Vector3D(random() * 20, random() * 5, random() * 20))
			];
			var distances = [for (i in 0...18) [for (j in 0...18) i == j ? 0. : Math.POSITIVE_INFINITY]];
			for (i in 0...18)
				for (j in 0...18)
					if (i != j && random() < 0.2) {
						var cost = random() < 0.1 ? 0. : random() * 8;
						g.connect(nodes[i], nodes[j], cost);
						distances[i][j] = cost;
					}
			for (k in 0...18)
				for (i in 0...18)
					for (j in 0...18)
						distances[i][j] = Math.min(distances[i][j], distances[i][k] + distances[k][j]);
			for (i in 0...18)
				for (j in 0...18) {
					var answer = g.findPath(nodes[i], nodes[j]);
					var expected = distances[i][j];
					check(expected == Math.POSITIVE_INFINITY ? answer.status == NavPathStatus3D.UNREACHABLE : answer.status == NavPathStatus3D.FOUND
						&& Math.abs(expected - answer.cost) < 1e-8,
						"独立最短路对照失败");
				}
			g.dispose();
		}
		trace("HXMAKER_NAV_GRAPH_CHECKS PASS：3888 组独立最短路对照及边界断言");
	}
}
