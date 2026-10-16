package hx.collision3d;

import hx.geom.Ray3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 独立查询世界；借用显式注册的碰撞代理，不注册帧回调，不驱动刚体。 */
class CollisionWorld3D {
	public var isDisposed(default, null):Bool = false;
	public var colliders(get, never):Array<Collider3D>;
	private var entries:Array<Collider3D> = [];
	public function new() {}
	private function get_colliders():Array<Collider3D> { return entries.copy(); }
	private function checkAlive():Void { if (isDisposed) throw "碰撞世界已经销毁"; }
	public function add<T:Collider3D>(value:T):T {
		checkAlive(); if (value == null) throw "碰撞体不能为空"; value.validate();
		if (value.world == this) return value;
		if (value.world != null) throw "碰撞体必须先从原世界注销";
		entries.push(value); value.setWorld(this); return value;
	}
	public function remove(value:Collider3D):Void {
		if (value != null && entries.remove(value)) value.setWorld(null);
	}
	public function clear():Void { for (value in entries) value.setWorld(null); entries = []; }
	public function dispose():Void { if (isDisposed) return; clear(); isDisposed = true; }
	private function accepts(value:Collider3D,mask:Int,includeTriggers:Bool):Bool {
		return !value.isDisposed && value.enabled && (value.layer & mask) != 0 && (includeTriggers || !value.isTrigger)
			&& (value.node == null || !value.node.isDisposed);
	}
	public function overlapSphere(center:Vector3D,radius:Float,mask:Int = -1,includeTriggers:Bool = false):Array<CollisionHit3D> {
		return overlapCapsule(center,radius,radius*2,mask,includeTriggers);
	}
	/** center 为世界中心，height 包含两端半球；接触也算重叠，penetration 可为零。 */
	public function overlapCapsule(center:Vector3D,radius:Float,height:Float,mask:Int = -1,includeTriggers:Bool = false):Array<CollisionHit3D> {
		checkAlive(); CollisionMath3D.capsule(center,radius,height); var result:Array<CollisionHit3D> = [];
		for (value in entries) if (accepts(value,mask,includeTriggers)) {
			var bounds = value.getWorldBounds();
			if (center.x+radius < bounds.min.x || center.x-radius > bounds.max.x || center.y+height/2 < bounds.min.y
				|| center.y-height/2 > bounds.max.y || center.z+radius < bounds.min.z || center.z-radius > bounds.max.z) continue;
			var sample = value.sampleCapsule(center,radius,height);
			if (sample.separation <= 0) result.push(new CollisionHit3D(value,sample.point,sample.normal,0,0,-sample.separation,false,sample.surfaceNormal));
		}
		return result;
	}
	public function sweepSphere(center:Vector3D,radius:Float,displacement:Vector3D,mask:Int = -1,includeTriggers:Bool = false,skin:Float = 1e-5):CollisionHit3D {
		return sweepCapsule(center,radius,radius*2,displacement,mask,includeTriggers,skin);
	}
	/** 对整段位移保守推进；不会依靠离散终点重叠判断高速运动。 */
	public function sweepCapsule(center:Vector3D,radius:Float,height:Float,displacement:Vector3D,mask:Int = -1,
		includeTriggers:Bool = false,skin:Float = 1e-5):CollisionHit3D {
		checkAlive(); CollisionMath3D.capsule(center,radius,height); CollisionMath3D.vector(displacement);
		var length = displacement.length;
		CollisionMath3D.vector(center.add(displacement));
		if (!Math3D.finite(length) || !Math3D.finite(skin) || skin < 0) throw "扫掠距离与接触余量无效";
		var best:CollisionHit3D = null;
		for (value in entries) if (accepts(value,mask,includeTriggers)) {
			var box = value.getWorldBounds(), fraction = 0., position = center.clone();
			// 扫掠包围盒初筛，精确距离负责胶囊圆角。
			if (Math.max(center.x,center.x+displacement.x)+radius+skin < box.min.x || Math.min(center.x,center.x+displacement.x)-radius-skin > box.max.x
				|| Math.max(center.y,center.y+displacement.y)+height/2+skin < box.min.y || Math.min(center.y,center.y+displacement.y)-height/2-skin > box.max.y
				|| Math.max(center.z,center.z+displacement.z)+radius+skin < box.min.z || Math.min(center.z,center.z+displacement.z)-radius-skin > box.max.z) continue;
			for (iteration in 0...64) {
				var sample = value.sampleCapsule(position,radius,height), closing = -sample.normal.dotProduct(displacement);
				var initialOverlap = fraction == 0 && sample.separation < -1e-8;
				if (initialOverlap || (sample.separation <= skin+1e-8 && closing > 1e-12) || iteration == 63) {
					var hit = new CollisionHit3D(value,sample.point,sample.normal,length*fraction,fraction,Math.max(0,-sample.separation),iteration == 63 && sample.separation > skin+1e-8,sample.surfaceNormal);
					if (best == null || hit.fraction < best.fraction) best = hit;
					break;
				}
				if (length == 0 || closing <= 1e-12) break;
				fraction += Math.max(0,(sample.separation-skin)/closing);
				if (fraction > 1 || (best != null && fraction > best.fraction)) break;
				position.setTo(center.x+displacement.x*fraction,center.y+displacement.y*fraction,center.z+displacement.z*fraction);
			}
		}
		return best;
	}
	/** 射线只查询碰撞代理，起点在代理内部时返回 distance=0 与最近推出面法线。 */
	public function raycast(ray:Ray3D,maxDistance:Null<Float> = null,mask:Int = -1,includeTriggers:Bool = false):CollisionHit3D {
		checkAlive(); if (ray == null) throw "碰撞射线不能为空";
		var limit:Float = maxDistance == null ? Math.POSITIVE_INFINITY : maxDistance;
		if (Math.isNaN(limit) || limit < 0) throw "射线距离无效";
		var source = new Ray3D(ray.origin,ray.direction), best:CollisionHit3D = null;
		for (value in entries) if (accepts(value,mask,includeTriggers)) {
			var hit = value.raycast(source,best == null ? limit : best.distance);
			if (hit != null && (best == null || hit.distance < best.distance)) best = hit;
		}
		return best;
	}
}
