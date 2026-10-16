package hx.controls3d;

import hx.collision3d.CharacterMoveResult3D;
import hx.collision3d.CollisionHit3D;
import hx.collision3d.CollisionMath3D;
import hx.collision3d.CollisionWorld3D;
import hx.display.Node3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 世界 Y 轴竖直的运动学胶囊，位置代表脚底；只在显式调用时移动借用节点。 */
class CharacterController3D {
	public var world(default, null):CollisionWorld3D;
	public var node(default, null):Node3D;
	public var isDisposed(default, null):Bool = false;
	public var radius:Float;
	public var height:Float;
	public var collisionMask:Int = -1;
	public var skinWidth:Float = 0.002;
	public var groundSnapDistance:Float = 0.12;
	public var minGroundNormalY:Float = 0.7;
	public var gravity:Float = -20;
	public var maxFallSpeed:Float = 30;
	public var maxSlideIterations:Int = 8;
	public var maxRecoveryIterations:Int = 12;
	public var grounded(default, null):Bool = false;
	public var verticalVelocity(default, null):Float = 0;
	public var lastResult(default, null):CharacterMoveResult3D;
	/** 返回世界脚底位置的副本；主动改变位置请使用 teleport。 */
	public var position(get, never):Vector3D;
	private var feet:Vector3D;
	private function get_position():Vector3D { return feet.clone(); }
	public function new(world:CollisionWorld3D,node:Node3D,radius:Float = 0.35,height:Float = 1.8) {
		if (world == null || world.isDisposed || node == null || node.isDisposed) throw "角色控制器需要有效碰撞世界与节点";
		this.world = world; this.node = node; this.radius = radius; this.height = height; feet = node.getWorldPosition(); validate();
	}
	private function validate():Void {
		if (isDisposed || world == null || world.isDisposed || node == null || node.isDisposed) throw "角色控制器已经失效";
		CollisionMath3D.capsule(feet,radius,height);
		for (value in [skinWidth,groundSnapDistance,minGroundNormalY,gravity,maxFallSpeed]) if (!Math3D.finite(value)) throw "角色运动参数必须有限";
		if (skinWidth <= 0 || skinWidth >= radius || groundSnapDistance < 0 || minGroundNormalY <= 0 || minGroundNormalY > 1
			|| gravity > 0 || maxFallSpeed <= 0 || maxSlideIterations < 1 || maxSlideIterations > 64 || maxRecoveryIterations < 1 || maxRecoveryIterations > 64)
			throw "角色运动参数范围无效";
	}
	private function parentInverse():Matrix3D {
		if (node.parent == null) return null;
		var inverse = node.parent.getWorldMatrix();
		if (Math.abs(inverse.determinant) < 1e-12 || !inverse.invert()) throw "角色节点父变换不可逆";
		return inverse;
	}
	private function applyNode(inverse:Matrix3D):Void {
		var local = inverse == null ? feet : inverse.transformVector(feet); CollisionMath3D.vector(local); node.setPosition(local.x,local.y,local.z);
	}
	private function center(position:Vector3D):Vector3D { return new Vector3D(position.x,position.y+height/2,position.z); }
	private static function scaled(value:Vector3D,factor:Float):Vector3D { return new Vector3D(value.x*factor,value.y*factor,value.z*factor); }
	/** 不扫描传送路径；随后 move 会解除目标处的初始重叠。 */
	public function teleport(position:Vector3D):Void {
		validate(); CollisionMath3D.vector(position); var inverse = parentInverse();
		var local = inverse == null ? position : inverse.transformVector(position); CollisionMath3D.vector(local);
		feet = position.clone(); verticalVelocity = 0; grounded = false; lastResult = null; node.setPosition(local.x,local.y,local.z);
	}
	public function jump(speed:Float):Bool {
		validate(); if (!Math3D.finite(speed) || speed <= 0) throw "起跳速度必须为正有限数值";
		if (!grounded) return false;
		verticalVelocity = speed; grounded = false; return true;
	}
	/** 速度单位为世界单位每秒，仅使用 X/Z；Y 由重力、jump 与碰撞控制。 */
	public function update(dt:Float,horizontalVelocity:Vector3D):CharacterMoveResult3D {
		validate(); CollisionMath3D.vector(horizontalVelocity);
		if (!Math3D.finite(dt) || dt < 0 || horizontalVelocity.y != 0) throw "时间步长必须非负且水平速度 Y 必须为零";
		var initial = Math.max(-maxFallSpeed,grounded && verticalVelocity < 0 ? 0 : verticalVelocity);
		var accelerationTime = gravity < 0 ? Math.min(dt,Math.max(0,(initial+maxFallSpeed)/-gravity)) : dt;
		var next = Math.max(-maxFallSpeed,initial+gravity*accelerationTime);
		var dy = initial*accelerationTime+0.5*gravity*accelerationTime*accelerationTime+next*(dt-accelerationTime);
		var result = move(new Vector3D(horizontalVelocity.x*dt,dy,horizontalVelocity.z*dt));
		verticalVelocity = result.grounded && next <= 0 || result.hitCeiling && next > 0 ? 0 : next;
		return result;
	}
	/** 位移接口不自动推进重力。整段扫掠后沿接触面滑动，独立于帧调度。 */
	public function move(displacement:Vector3D):CharacterMoveResult3D {
		validate(); CollisionMath3D.vector(displacement);
		if (!Math3D.finite(displacement.length)) throw "角色位移超出有限范围";
		var inverse = parentInverse(), start = feet.clone(), position = feet.clone(), result = new CharacterMoveResult3D();
		// 初始穿插使用最深接触推出；预算耗尽明确返回 stuck，不继续向障碍另一侧移动。
		for (iteration in 0...maxRecoveryIterations) {
			var deepest:CollisionHit3D = null;
			for (hit in world.overlapCapsule(center(position),radius,height,collisionMask))
				if (hit.penetration > 1e-8 && (deepest == null || hit.penetration > deepest.penetration)) deepest = hit;
			if (deepest == null) break;
			result.contacts.push(deepest); position = position.add(scaled(deepest.normal,deepest.penetration+skinWidth));
		}
		for (hit in world.overlapCapsule(center(position),radius,height,collisionMask)) if (hit.penetration > 1e-8) { result.stuck = true; result.blocked = true; break; }
		var remaining = displacement.clone(), planes:Array<Vector3D> = [];
		if (!result.stuck) for (iteration in 0...maxSlideIterations) {
			if (remaining.length < 1e-10) break;
			var hit = world.sweepCapsule(center(position),radius,height,remaining,collisionMask,false,skinWidth);
			if (hit == null) { position = position.add(remaining); remaining.setTo(0,0,0); break; }
			result.contacts.push(hit); result.blocked = true;
			if (hit.normal.y < -minGroundNormalY) result.hitCeiling = true;
			position = position.add(scaled(remaining,hit.fraction));
			remaining.scaleBy(1-hit.fraction);
			var duplicate = false; for (normal in planes) if (normal.dotProduct(hit.normal) > 0.9999) duplicate = true;
			if (!duplicate) planes.push(hit.normal);
			remaining = slide(remaining,planes);
		}
		result.iterationLimited = !result.stuck && remaining.length >= 1e-10;
		// 上升时不吸回地面；落地只接受朝上的支撑面，避免墙边被误判成站立。
		if (!result.stuck && displacement.y <= 0) {
			var ground = world.sweepCapsule(center(position),radius,height,new Vector3D(0,-Math.max(groundSnapDistance,skinWidth*2),0),collisionMask,false,skinWidth);
			if (ground != null && !ground.conservative && ground.normal.y >= minGroundNormalY) {
				position.y -= ground.distance; result.grounded = true; result.contacts.push(ground);
			}
		}
		CollisionMath3D.vector(position);
		var local = inverse == null ? position : inverse.transformVector(position); CollisionMath3D.vector(local);
		feet = position; grounded = result.grounded; result.displacement = position.subtract(start); lastResult = result; applyNode(inverse); return result;
	}
	/** 优先尝试各接触面的切向；两面冲突时沿交线移动，封闭角落停止。 */
	private function slide(velocity:Vector3D,planes:Array<Vector3D>):Vector3D {
		var allowed = true; for (normal in planes) if (velocity.dotProduct(normal) < -1e-10) allowed = false;
		if (allowed) return velocity;
		for (normal in planes) {
			var clipped = velocity.subtract(scaled(normal,Math.min(0,velocity.dotProduct(normal)))), valid = true;
			for (other in planes) if (clipped.dotProduct(other) < -1e-10) valid = false;
			if (valid) return clipped;
		}
		if (planes.length >= 2) {
			var axis = planes[0].crossProduct(planes[1]);
			if (axis.length > 1e-8) {
				axis.normalize(); axis.scaleBy(velocity.dotProduct(axis));
				var valid = true; for (normal in planes) if (axis.dotProduct(normal) < -1e-10) valid = false;
				if (valid) return axis;
			}
		}
		return new Vector3D();
	}
	public function dispose():Void { if (isDisposed) return; isDisposed = true; world = null; node = null; lastResult = null; }
}
