package hx.collision3d;

import hx.geom.Vector3D;

/** 世界坐标查询快照；collider 为借用引用，normal 指向碰撞体外侧。 */
class CollisionHit3D {
	/** 命中的碰撞代理借用引用，不转移所有权。 */
	public var collider(default, null):Collider3D;

	/** 世界空间接触点。 */
	public var point(default, null):Vector3D;

	/** 世界空间单位分离法线，从碰撞表面朝向查询形状。 */
	public var normal(default, null):Vector3D;

	/** 实际支撑面方向，与胶囊圆角产生的分离法线分开。 */
	public var surfaceNormal(default, null):Vector3D;

	/** 从查询起点到接触位置的世界距离；重叠查询为零。 */
	public var distance(default, null):Float;

	/** 扫掠完成比例；重叠和射线查询为零。 */
	public var fraction(default, null):Float;

	/** 重叠深度的非负大小；单纯接触时为零。 */
	public var penetration(default, null):Float;

	/** 达到扫掠迭代上限时返回保守阻挡，不冒险跨越尚未确认的区间。 */
	public var conservative(default, null):Bool;

	/** 创建查询结果并复制接触点及法线；未传入表面法线时使用分离法线。 */
	public function new(collider:Collider3D, point:Vector3D, normal:Vector3D, distance:Float = 0, fraction:Float = 0, penetration:Float = 0,
			conservative:Bool = false, surfaceNormal:Vector3D = null) {
		this.collider = collider;
		this.point = point.clone();
		this.normal = normal.clone();
		this.surfaceNormal = surfaceNormal == null ? normal.clone() : surfaceNormal.clone();
		this.distance = distance;
		this.fraction = fraction;
		this.penetration = penetration;
		this.conservative = conservative;
	}
}
