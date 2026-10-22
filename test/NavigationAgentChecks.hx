import hx.navigation3d.NavGraph3D;
import hx.navigation3d.NavAgent3D;
import hx.navigation3d.NavAgentState3D;
import hx.controls3d.CharacterController3D;
import hx.collision3d.CollisionWorld3D;
import hx.collision3d.BoxCollider3D;
import hx.display3d.Node3D;
import hx.geom.Vector3D;

/** 真实碰撞世界中的数值断言，不依赖角色资源或渲染。 */
class NavigationAgentChecks {
	static var count:Int;

	static function check(value:Bool, message:String):Void {
		count++;
		if (!value)
			throw "导航代理断言失败：" + message;
	}

	public static function run():Void {
		count = 0;
		var world = new CollisionWorld3D(), floorNode = new Node3D();
		floorNode.y = -0.5;
		var floor = world.add(new BoxCollider3D(40, 1, 40, floorNode));
		var node = new Node3D();
		node.y = 0.002;
		var controller = new CharacterController3D(world, node),
			graph = new NavGraph3D();
		var a = graph.addNode(new Vector3D(0, 0.002, 0)),
			b = graph.addNode(new Vector3D(3, 0.002, 0)),
			c = graph.addNode(new Vector3D(3, 0.002, 3));
		graph.connectBoth(a, b);
		var gates = graph.connectBoth(b, c);
		var agent = new NavAgent3D(graph, controller);
		agent.maxAttachDistance = 6;
		check(agent.setDestination(c, a), "合法路线规划失败");
		agent.update(0);
		check(agent.waypointIndex == 0, "零时间步推进了路径");
		for (i in 0...30)
			agent.update(1 / 60);
		var previous = controller.position;
		agent.pause();
		for (i in 0...60)
			agent.update(1 / 60);
		check(agent.state == NavAgentState3D.PAUSED && Math.abs(controller.position.x - previous.x) < 1e-6, "暂停时仍有水平移动");
		agent.resume();
		for (i in 0...250)
			agent.update(1 / 60);
		check(agent.state == NavAgentState3D.ARRIVED && controller.position.subtract(c.position).length < 0.15, "拐点路线未到达");
		agent.stop();
		check(agent.destination == null && agent.path == null && agent.state == NavAgentState3D.IDLE, "停止未清理目标");
		controller.teleport(a.position);
		check(agent.setDestination(c, a), "重新设置目标失败");
		for (edge in gates)
			edge.enabled = false;
		agent.update(1 / 60);
		check(agent.state == NavAgentState3D.NO_PATH, "图变化未重规划断路");
		for (edge in gates)
			edge.enabled = true;
		check(agent.repath(), "通路恢复后重规划失败");
		var wallNode = new Node3D();
		wallNode.setPosition(1.5, 1.5, 0);
		var wall = world.add(new BoxCollider3D(0.4, 3, 4, wallNode));
		for (i in 0...240)
			agent.update(1 / 60);
		check(agent.state == NavAgentState3D.BLOCKED && controller.position.x < 1.2, "物理受阻未停止或发生穿墙");
		controller.teleport(a.position);
		agent.stop();
		check(!agent.setDestination(b, b) && agent.failureReason != "", "显式起点绕过安全接入检查");
		wall.dispose();
		wallNode.dispose();
		var high = graph.addNode(new Vector3D(0, 3, 0));
		graph.connect(a, high);
		check(agent.setDestination(high, a), "高层目标规划失败");
		for (i in 0...180)
			agent.update(1 / 60);
		check(agent.state == NavAgentState3D.BLOCKED, "同水平位置的不同楼层被误报到达");
		controller.teleport(a.position);
		check(agent.setDestination(c, a), "销毁前规划失败");
		graph.removeNode(c);
		agent.update(1 / 60);
		check(agent.state == NavAgentState3D.NO_PATH, "已移除目标仍被跟随");
		agent.dispose();
		agent.dispose();
		check(!controller.isDisposed && !graph.isDisposed && agent.isDisposed, "代理销毁错误接管借用资源");
		controller.dispose();
		node.dispose();
		floor.dispose();
		floorNode.dispose();
		world.dispose();
		graph.dispose();
		trace("HXMAKER_NAV_AGENT_CHECKS PASS 检查数：" + count);
	}
}
