package hx.collision3d;

import hx.geom.Vector3D;

/** 世界坐标查询快照；collider 为借用引用，normal 指向碰撞体外侧。 */
class CollisionHit3D {
	public var collider(default, null):BoxCollider3D;
	public var point(default, null):Vector3D;
	public var normal(default, null):Vector3D;
	public var distance(default, null):Float;
	/** 扫掠完成比例；重叠和射线查询为零。 */
	public var fraction(default, null):Float;
	public var penetration(default, null):Float;
	/** 达到扫掠迭代上限时返回保守阻挡，不冒险跨越尚未确认的区间。 */
	public var conservative(default, null):Bool;
	public function new(collider:BoxCollider3D, point:Vector3D, normal:Vector3D, distance:Float = 0,
		fraction:Float = 0, penetration:Float = 0, conservative:Bool = false) {
		this.collider = collider; this.point = point.clone(); this.normal = normal.clone();
		this.distance = distance; this.fraction = fraction; this.penetration = penetration; this.conservative = conservative;
	}
}
