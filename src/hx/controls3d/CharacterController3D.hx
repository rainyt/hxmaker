package hx.controls3d;

import hx.collision3d.CharacterMoveResult3D;
import hx.collision3d.CollisionHit3D;
import hx.collision3d.CollisionMath3D;
import hx.collision3d.CollisionWorld3D;
import hx.display3d.Node3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 世界 Y 轴竖直的运动学胶囊，位置代表脚底；只在显式调用时移动借用节点。 */
class CharacterController3D {
	/** 借用的碰撞世界；控制器不接管其销毁。 */
	public var world(default, null):CollisionWorld3D;

	/** 借用的显示节点；世界脚底位置由控制器拥有，动画应只作用于其子节点。 */
	public var node(default, null):Node3D;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 世界胶囊半径，必须为正；不随显示节点缩放改变。 */
	public var radius:Float;

	/** 世界胶囊总高度，包含半球，必须不小于两倍半径。 */
	public var height:Float;

	/** 碰撞层位掩码，默认 -1 查询全部层；忽略触发器。 */
	public var collisionMask:Int = -1;

	/** 接触安全间距，默认 0.002 世界单位，须大于零且小于半径。 */
	public var skinWidth:Float = 0.002;

	/** 向下贴地距离，默认 0.12 世界单位；上升期间不贴地。 */
	public var groundSnapDistance:Float = 0.12;

	/** 可支撑表面的最小单位法线 Y，范围 (0,1]，可通过 maxSlopeAngle 设置。 */
	public var minGroundNormalY:Float = 0.7;

	/** 零保留原有行为；仅在有支撑且未起跳时尝试跨越台阶。 */
	public var stepOffset:Float = 0;

	/** 最大可行走坡度，单位为度，范围 [0,90)；与 minGroundNormalY 同步。 */
	public var maxSlopeAngle(get, set):Float;

	/** 世界 Y 轴重力加速度，默认 -20 世界单位每平方秒，不能为正。 */
	public var gravity:Float = -20;

	/** 下落终端速度的正数大小，默认 30 世界单位每秒。 */
	public var maxFallSpeed:Float = 30;

	/** 每次运动的接触滑动预算，默认 8，允许 1 至 64。 */
	public var maxSlideIterations:Int = 8;

	/** 解除初始重叠的最大迭代数，默认 12，允许 1 至 64。 */
	public var maxRecoveryIterations:Int = 12;

	/** 最近一次运动是否获得可行走表面的支撑。 */
	public var grounded(default, null):Bool = false;

	/** 当前世界 Y 轴速度；由 update、jump 和 teleport 管理。 */
	public var verticalVelocity(default, null):Float = 0;

	/** 最近一次运动结果；尚未移动或刚传送时为 null。 */
	public var lastResult(default, null):CharacterMoveResult3D;

	/** 返回世界脚底位置的副本；主动改变位置请使用 teleport。 */
	public var position(get, never):Vector3D;

	private var feet:Vector3D;

	private function get_position():Vector3D {
		return feet.clone();
	}

	private function get_maxSlopeAngle():Float {
		return Math.acos(minGroundNormalY) * 180 / Math.PI;
	}

	private function set_maxSlopeAngle(value:Float):Float {
		if (!Math3D.finite(value) || value < 0 || value >= 90)
			throw "坡度上限必须位于零至九十度之间，不含九十度";
		minGroundNormalY = Math.cos(value * Math.PI / 180);
		return value;
	}

	/** 借用世界与节点并读取初始世界脚底位置；半径和高度以世界单位计。 */
	public function new(world:CollisionWorld3D, node:Node3D, radius:Float = 0.35, height:Float = 1.8) {
		if (world == null || world.isDisposed || node == null || node.isDisposed)
			throw "角色控制器需要有效碰撞世界与节点";
		this.world = world;
		this.node = node;
		this.radius = radius;
		this.height = height;
		feet = node.getWorldPosition();
		validate();
	}

	private function validate():Void {
		if (isDisposed || world == null || world.isDisposed || node == null || node.isDisposed)
			throw "角色控制器已经失效";
		CollisionMath3D.capsule(feet, radius, height);
		for (value in [
			skinWidth,
			groundSnapDistance,
			minGroundNormalY,
			gravity,
			maxFallSpeed,
			stepOffset
		])
			if (!Math3D.finite(value))
				throw "角色运动参数必须有限";
		if (skinWidth <= 0 || skinWidth >= radius || groundSnapDistance < 0 || minGroundNormalY <= 0 || minGroundNormalY > 1 || stepOffset < 0
			|| gravity > 0 || maxFallSpeed <= 0 || maxSlideIterations < 1 || maxSlideIterations > 64 || maxRecoveryIterations < 1 || maxRecoveryIterations > 64)
			throw "角色运动参数范围无效";
	}

	private function parentInverse():Matrix3D {
		if (node.parent == null)
			return null;
		var inverse = node.parent.getWorldMatrix();
		if (Math.abs(inverse.determinant) < 1e-12 || !inverse.invert())
			throw "角色节点父变换不可逆";
		return inverse;
	}

	private function applyNode(inverse:Matrix3D):Void {
		var local = inverse == null ? feet : inverse.transformVector(feet);
		CollisionMath3D.vector(local);
		node.setPosition(local.x, local.y, local.z);
	}

	private function center(position:Vector3D):Vector3D {
		return new Vector3D(position.x, position.y + height / 2, position.z);
	}

	private static function scaled(value:Vector3D, factor:Float):Vector3D {
		return new Vector3D(value.x * factor, value.y * factor, value.z * factor);
	}

	private function probeGround(position:Vector3D, distance:Float):CollisionHit3D {
		var hit = world.sweepCapsule(center(position), radius, height, new Vector3D(0, -distance, 0), collisionMask, false, skinWidth);
		return hit != null && !hit.conservative && hit.normal.y > 0 && hit.surfaceNormal.y >= minGroundNormalY ? hit : null;
	}

	/** 升起、前进、落脚都做胶囊扫掠，任一阶段空间不足就放弃，不修改真实节点。 */
	private function tryStep(position:Vector3D, remaining:Vector3D):CharacterStep3D {
		var horizontal = new Vector3D(remaining.x, 0, remaining.z);
		if (horizontal.length <= skinWidth)
			return null;
		var lift = stepOffset + skinWidth * 2, up = new Vector3D(0, lift, 0);
		var ceiling = world.sweepCapsule(center(position), radius, height, up, collisionMask, false, skinWidth);
		if (ceiling != null && ceiling.fraction < 1)
			return null;
		var raised = position.add(up),
			obstacle = world.sweepCapsule(center(raised), radius, height, horizontal, collisionMask, false, skinWidth);
		var fraction = obstacle == null ? 1. : obstacle.fraction;
		if (horizontal.length * fraction <= skinWidth)
			return null;
		var candidate = raised.add(scaled(horizontal, fraction)),
			landing = probeGround(candidate, lift + groundSnapDistance);
		if (landing == null)
			return null;
		candidate.y -= landing.distance;
		var rise = candidate.y - position.y;
		if (rise <= skinWidth / 2 || rise > stepOffset + skinWidth * 2 || landing.point.y - position.y > stepOffset + skinWidth * 2)
			return null;
		for (hit in world.overlapCapsule(center(candidate), radius, height, collisionMask))
			if (hit.penetration > 1e-7)
				return null;
		return {position: candidate, landing: landing};
	}

	/** 不扫描传送路径；随后 move 会解除目标处的初始重叠。 */
	public function teleport(position:Vector3D):Void {
		validate();
		CollisionMath3D.vector(position);
		var inverse = parentInverse();
		var local = inverse == null ? position : inverse.transformVector(position);
		CollisionMath3D.vector(local);
		feet = position.clone();
		verticalVelocity = 0;
		grounded = false;
		lastResult = null;
		node.setPosition(local.x, local.y, local.z);
	}

	/** 已接地时设置正的向上速度并返回 true；空中返回 false，不重复起跳。 */
	public function jump(speed:Float):Bool {
		validate();
		if (!Math3D.finite(speed) || speed <= 0)
			throw "起跳速度必须为正有限数值";
		if (!grounded)
			return false;
		verticalVelocity = speed;
		grounded = false;
		return true;
	}

	/** 速度单位为世界单位每秒，仅使用 X/Z；Y 由重力、jump 与碰撞控制。 */
	public function update(dt:Float, horizontalVelocity:Vector3D):CharacterMoveResult3D {
		validate();
		CollisionMath3D.vector(horizontalVelocity);
		if (!Math3D.finite(dt) || dt < 0 || horizontalVelocity.y != 0)
			throw "时间步长必须非负且水平速度 Y 必须为零";
		var initial = Math.max(-maxFallSpeed, grounded && verticalVelocity < 0 ? 0 : verticalVelocity);
		var accelerationTime = gravity < 0 ? Math.min(dt, Math.max(0, (initial + maxFallSpeed) / -gravity)) : dt;
		var next = Math.max(-maxFallSpeed, initial + gravity * accelerationTime);
		var dy = initial * accelerationTime + 0.5 * gravity * accelerationTime * accelerationTime + next * (dt - accelerationTime);
		var result = move(new Vector3D(horizontalVelocity.x * dt, dy, horizontalVelocity.z * dt));
		verticalVelocity = result.grounded && next <= 0 || result.hitCeiling && next > 0 ? 0 : next;
		return result;
	}

	/** 位移接口不自动推进重力。整段扫掠后沿接触面滑动，独立于帧调度。 */
	public function move(displacement:Vector3D):CharacterMoveResult3D {
		validate();
		CollisionMath3D.vector(displacement);
		if (!Math3D.finite(displacement.length))
			throw "角色位移超出有限范围";
		var inverse = parentInverse(),
			start = feet.clone(),
			position = feet.clone(),
			result = new CharacterMoveResult3D();
		// 初始穿插使用最深接触推出；预算耗尽明确返回 stuck，不继续向障碍另一侧移动。
		for (iteration in 0...maxRecoveryIterations) {
			var deepest:CollisionHit3D = null;
			for (hit in world.overlapCapsule(center(position), radius, height, collisionMask))
				if (hit.penetration > 1e-8 && (deepest == null || hit.penetration > deepest.penetration))
					deepest = hit;
			if (deepest == null)
				break;
			result.contacts.push(deepest);
			position = position.add(scaled(deepest.normal, deepest.penetration + skinWidth));
		}
		for (hit in world.overlapCapsule(center(position), radius, height, collisionMask))
			if (hit.penetration > 1e-8) {
				result.stuck = true;
				result.blocked = true;
				break;
			}
		var remaining = displacement.clone(), planes:Array<Vector3D> = [];
		var support = !result.stuck && displacement.y <= 0 ? probeGround(position, skinWidth * 2) : null;
		if (support != null) {
			// 保持请求的 X/Z 速度，在可行走支撑面上补足 Y；站立时不沿缓坡缓慢下滑。
			var normal = support.surfaceNormal;
			remaining.y = -(normal.x * remaining.x + normal.z * remaining.z) / normal.y;
		}
		if (!result.stuck)
			for (iteration in 0...maxSlideIterations) {
				if (remaining.length < 1e-10)
					break;
				var hit = world.sweepCapsule(center(position), radius, height, remaining, collisionMask, false, skinWidth);
				if (hit == null) {
					position = position.add(remaining);
					remaining.setTo(0, 0, 0);
					break;
				}
				result.contacts.push(hit);
				result.blocked = true;
				if (hit.normal.y < -minGroundNormalY)
					result.hitCeiling = true;
				position = position.add(scaled(remaining, hit.fraction));
				remaining.scaleBy(1 - hit.fraction);
				if (stepOffset > 0 && support != null && displacement.y <= 0 && hit.normal.y < minGroundNormalY) {
					var step = tryStep(position, remaining);
					if (step != null) {
						position = step.position;
						remaining.setTo(0, 0, 0);
						result.stepped = true;
						result.grounded = true;
						result.groundNormal = step.landing.surfaceNormal.clone();
						result.contacts.push(step.landing);
						break;
					}
				}
				var duplicate = false;
				for (normal in planes)
					if (normal.dotProduct(hit.normal) > 0.9999)
						duplicate = true;
				if (!duplicate)
					planes.push(hit.normal);
				if (hit.normal.y > 0 && hit.surfaceNormal.y > 0 && hit.surfaceNormal.y < minGroundNormalY) {
					// 额外限制朝陡坡上方的水平运动；真实接触面仍保留，以允许重力下滑。
					var wall = new Vector3D(hit.surfaceNormal.x, 0, hit.surfaceNormal.z);
					if (wall.length > 1e-8) {
						wall.normalize();
						planes.push(wall);
						result.slopeLimited = true;
					}
				}
				remaining = slide(remaining, planes);
			}
		result.iterationLimited = !result.stuck && remaining.length >= 1e-10;
		// 上升时不吸回地面；落地只接受朝上的支撑面，避免墙边被误判成站立。
		if (!result.stuck && displacement.y <= 0) {
			var ground = probeGround(position, Math.max(groundSnapDistance, skinWidth * 2));
			if (ground != null) {
				position.y -= ground.distance;
				result.grounded = true;
				result.groundNormal = ground.surfaceNormal.clone();
				result.contacts.push(ground);
			}
		}
		CollisionMath3D.vector(position);
		var local = inverse == null ? position : inverse.transformVector(position);
		CollisionMath3D.vector(local);
		feet = position;
		grounded = result.grounded;
		result.displacement = position.subtract(start);
		lastResult = result;
		applyNode(inverse);
		return result;
	}

	/** 优先尝试各接触面的切向；两面冲突时沿交线移动，封闭角落停止。 */
	private function slide(velocity:Vector3D, planes:Array<Vector3D>):Vector3D {
		var allowed = true;
		for (normal in planes)
			if (velocity.dotProduct(normal) < -1e-10)
				allowed = false;
		if (allowed)
			return velocity;
		for (normal in planes) {
			var clipped = velocity.subtract(scaled(normal, Math.min(0, velocity.dotProduct(normal)))), valid = true;
			for (other in planes)
				if (clipped.dotProduct(other) < -1e-10)
					valid = false;
			if (valid)
				return clipped;
		}
		if (planes.length >= 2) {
			var axis = planes[0].crossProduct(planes[1]);
			if (axis.length > 1e-8) {
				axis.normalize();
				axis.scaleBy(velocity.dotProduct(axis));
				var valid = true;
				for (normal in planes)
					if (axis.dotProduct(normal) < -1e-10)
						valid = false;
				if (valid)
					return axis;
			}
		}
		return new Vector3D();
	}

	/** 幂等解除世界、节点与结果引用，不销毁借用对象。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		isDisposed = true;
		world = null;
		node = null;
		lastResult = null;
	}
}

private typedef CharacterStep3D = {var position:Vector3D; var landing:CollisionHit3D;}
