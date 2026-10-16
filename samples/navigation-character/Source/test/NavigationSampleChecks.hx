package test;

import hx.navigation3d.NavAgentState3D;

/** 仅在验收宏下运行，直接验证示例的真实几何、通路和角色控制器。 */
@:access(test.NavigationCharacterScene)
class NavigationSampleChecks {
	static var count:Int = 0;

	static function check(value:Bool, message:String):Void {
		count++;
		if (!value)
			throw "导航示例断言失败：" + message;
	}

	static function finish(scene:NavigationCharacterScene, frames:Int = 900):Void {
		for (i in 0...frames) {
			scene.agent.update(1 / 60);
			if (scene.agent.state != NavAgentState3D.MOVING)
				break;
		}
		check(scene.agent.state == NavAgentState3D.ARRIVED,
			"路线未到达："
			+ scene.agent.state
			+ " / "
			+ scene.agent.failureReason
			+ " / "
			+ scene.controller.position);
	}

	public static function run(scene:NavigationCharacterScene):Void {
		count = 0;
		scene.setDoor(true);
		scene.scenario(0, false);
		var shortCost = scene.agent.path.cost;
		finish(scene);
		scene.setDoor(false);
		scene.scenario(0, false);
		check(scene.agent.path.cost > shortCost + 5, "关门后未绕墙");
		finish(scene);
		scene.setDoor(true);
		scene.scenario(0, false);
		for (i in 0...25)
			scene.agent.update(1 / 60);
		var revision = scene.agent.path.revision;
		scene.setDoor(false);
		scene.agent.update(1 / 60);
		check(scene.agent.path.revision != revision && scene.agent.path.cost > shortCost, "行走中关门未重规划");
		finish(scene);
		scene.scenario(1, false);
		finish(scene);
		check(scene.controller.position.y > 1.5, "上楼梯高度错误");
		scene.scenario(1, true);
		finish(scene);
		check(scene.controller.position.y < 0.1, "下楼梯未落地");
		scene.scenario(2, false);
		finish(scene);
		check(scene.controller.position.y > 2.1, "上坡道高度错误");
		scene.scenario(2, true);
		finish(scene);
		check(scene.controller.position.y < 0.1, "下坡道未落地");
		scene.scenario(0, false);
		check(!scene.agent.setDestination(scene.routes[3][0]) && scene.agent.state == NavAgentState3D.NO_PATH, "高台应不可达");
		trace("HXMAKER_NAV_SAMPLE_CHECKS PASS 检查数：" + count);
		scene.setDoor(true);
		scene.scenario(0, false);
		scene.agent.stop();
	}
}
