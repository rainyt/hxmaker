package hx.navigation3d;

import hx.controls3d.CharacterController3D;
import hx.collision3d.CharacterMoveResult3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 借用导航图和角色控制器；业务每帧仅调用一次 update，再推进动画和相机。 */
class NavAgent3D {
	/** 借用的路点图，销毁代理不销毁图。 */
	public var graph(default, null):NavGraph3D;

	/** 借用的角色控制器，代理活动期间由本类独占其 update。 */
	public var controller(default, null):CharacterController3D;

	/** 当前状态。失败后需显式重新指定目标，不会每帧重复搜索。 */
	public var state(default, null):NavAgentState3D = NavAgentState3D.IDLE;

	/** 最近一次搜索结果；接入失败时为 null。 */
	public var path(default, null):NavPath3D;

	/** 最近一次失败的中文说明，正常规划或停止后清空。 */
	public var failureReason(default, null):String = "";

	/** 目标节点的借用引用；stop 或 dispose 后清空。 */
	public var destination(default, null):NavNode3D;

	/** 当前路径点下标，包含最初接入点；无需手动递增。 */
	public var waypointIndex(default, null):Int = 0;

	/** 水平速度，单位为世界单位每秒，默认 3。 */
	public var speed:Float = 3;

	/** 水平到达半径，默认 0.08 世界单位。 */
	public var arrivalRadius:Float = 0.08;

	/** 脚底高度到达容差，默认 0.25 世界单位。 */
	public var heightTolerance:Float = 0.25;

	/** 自动寻找起点时的最大三维距离，默认 6 世界单位。 */
	public var maxAttachDistance:Float = 6;

	/** 默认接入检查允许的高度差，默认 0.25；复杂台阶接入可提供 canAttach。 */
	public var maxAttachHeight:Float = 0.25;

	/** 持续未向当前路点取得进展的超时秒数，默认 1.5。 */
	public var blockedTimeout:Float = 1.5;

	/** 每次搜索的节点展开上限，默认 4096。 */
	public var maxVisited:Int = 4096;

	/** 图发生变化时自动重规划，默认开启；关闭时使旧路径停止并报告失败。 */
	public var autoRepath:Bool = true;

	/** 可选接入判定，输入世界脚底和候选点；替代默认胶囊直线扫掠，回调须无副作用。 */
	public var canAttach:Vector3D->NavNode3D->Bool;

	/** 是否已销毁。 */
	public var isDisposed(default, null):Bool = false;

	private var points:Array<Vector3D> = [];
	private var stalled:Float = 0;
	private var bestDistance:Float = Math.POSITIVE_INFINITY;
	private var paused:Bool = false;

	/** 创建代理，不注册全局帧循环或输入监听。 */
	public function new(graph:NavGraph3D, controller:CharacterController3D) {
		if (graph == null || graph.isDisposed || controller == null || controller.isDisposed)
			throw "导航代理需要有效图和角色控制器";
		this.graph = graph;
		this.controller = controller;
	}

	private function validate():Void {
		if (isDisposed || graph == null || graph.isDisposed || controller == null || controller.isDisposed)
			throw "导航代理已经失效";
		for (v in [
			speed,
			arrivalRadius,
			heightTolerance,
			maxAttachDistance,
			maxAttachHeight,
			blockedTimeout
		])
			if (!Math3D.finite(v) || v < 0)
				throw "导航参数必须非负有限";
		if (speed <= 0 || arrivalRadius <= 0 || blockedTimeout <= 0 || maxVisited < 1)
			throw "导航速度、半径、超时和预算必须为正";
	}

	private function attachable(position:Vector3D, node:NavNode3D):Bool {
		var point = node.position;
		if (point.subtract(position).length > maxAttachDistance)
			return false;
		if (canAttach != null)
			return canAttach(position.clone(), node);
		if (Math.abs(point.y - position.y) > maxAttachHeight)
			return false;
		var hit = controller.world.sweepCapsule(new Vector3D(position.x, position.y + controller.height / 2, position.z), controller.radius,
			controller.height, point.subtract(position), controller.collisionMask, false, controller.skinWidth);
		return hit == null || !hit.conservative && hit.fraction >= 1 - 1e-6;
	}

	/** 指定路点目标并同步规划；可显式给起点，但仍须通过距离及安全接入检查。返回是否找到路径。 */
	public function setDestination(goal:NavNode3D, start:NavNode3D = null):Bool {
		validate();
		destination = goal;
		paused = false;
		return plan(start);
	}

	private function plan(start:NavNode3D = null):Bool {
		path = null;
		points = [];
		waypointIndex = 0;
		stalled = 0;
		bestDistance = Math.POSITIVE_INFINITY;
		failureReason = "";
		if (destination == null || destination.graph != graph || !destination.enabled)
			return fail("目标路点已失效或禁用");
		var position = controller.position;
		if (start == null)
			start = graph.nearest(position, maxAttachDistance, node -> attachable(position, node));
		else if (start.graph != graph || !start.enabled || !attachable(position, start))
			return fail("指定起点无法安全接入");
		if (start == null)
			return fail("附近没有可安全接入的路点");
		path = graph.findPath(start, destination, maxVisited);
		if (path.status != NavPathStatus3D.FOUND)
			return fail(path.status == NavPathStatus3D.SEARCH_LIMIT ? "搜索预算用尽" : "目标不可达");
		points = path.points;
		state = paused ? NavAgentState3D.PAUSED : NavAgentState3D.MOVING;
		return true;
	}

	private function fail(reason:String):Bool {
		state = NavAgentState3D.NO_PATH;
		failureReason = reason;
		return false;
	}

	/** 立即清空路径和目标；不清除角色重力或改变位置。 */
	public function stop():Void {
		if (isDisposed)
			return;
		destination = null;
		path = null;
		points = [];
		waypointIndex = 0;
		paused = false;
		stalled = 0;
		failureReason = "";
		state = NavAgentState3D.IDLE;
	}

	/** 暂停水平导航，保留路径；update 仍维持角色重力与贴地。 */
	public function pause():Void {
		validate();
		if (state == NavAgentState3D.MOVING) {
			paused = true;
			state = NavAgentState3D.PAUSED;
		}
	}

	/** 恢复暂停路径，下次 update 检查图版本。 */
	public function resume():Void {
		validate();
		if (state == NavAgentState3D.PAUSED) {
			paused = false;
			state = NavAgentState3D.MOVING;
		}
	}

	/** 显式重规划；适用于障碍变化后由项目更新通路的情况。失败时保留目标供 UI 反馈。 */
	public function repath():Bool {
		validate();
		return plan();
	}

	/** 推进路径并且恰好调用一次控制器 update。dt 为非负秒数；零步长不推进超时或路径。 */
	public function update(dt:Float):CharacterMoveResult3D {
		validate();
		if (!Math3D.finite(dt) || dt < 0)
			throw "导航时间步长必须非负有限";
		var velocity = new Vector3D();
		if (dt > 0 && (state == NavAgentState3D.MOVING || state == NavAgentState3D.PAUSED) && path.revision != graph.revision) {
			if (autoRepath)
				plan();
			else
				fail("导航图已变化，请重新规划");
		}
		var active = dt > 0 && state == NavAgentState3D.MOVING;
		if (active) {
			advance();
			active = state == NavAgentState3D.MOVING;
			if (active) {
				var p = controller.position, target = points[waypointIndex];
				velocity.setTo(target.x - p.x, 0, target.z - p.z);
				var length = velocity.length;
				if (length > 1e-10)
					velocity.scaleBy(Math.min(speed, length / dt) / length);
			}
		}
		var result = controller.update(dt, velocity);
		if (active) {
			var distance = controller.position.subtract(points[waypointIndex]).length;
			if (bestDistance - distance > 0.001) {
				bestDistance = distance;
				stalled = 0;
			} else
				stalled += dt;
			advance();
			if (state == NavAgentState3D.MOVING && (result.stuck || stalled >= blockedTimeout)) {
				state = NavAgentState3D.BLOCKED;
				failureReason = "角色持续受阻，需更新通路后重新规划";
			}
		}
		return result;
	}

	private function advance():Void {
		var p = controller.position;
		while (waypointIndex < points.length) {
			var target = points[waypointIndex],
				dx = p.x - target.x,
				dz = p.z - target.z;
			if (dx * dx + dz * dz > arrivalRadius * arrivalRadius || Math.abs(p.y - target.y) > heightTolerance)
				break;
			waypointIndex++;
			stalled = 0;
			bestDistance = Math.POSITIVE_INFINITY;
		}
		if (waypointIndex == points.length)
			state = NavAgentState3D.ARRIVED;
	}

	/** 幂等解除引用，不销毁借用对象；之后不再允许更新。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		stop();
		isDisposed = true;
		graph = null;
		controller = null;
		canAttach = null;
	}
}
