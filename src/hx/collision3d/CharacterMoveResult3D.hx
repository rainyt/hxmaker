package hx.collision3d;

import hx.geom.Vector3D;

/** 一次显式运动的结果；位移包含脱离初始重叠与向下贴地修正。 */
class CharacterMoveResult3D {
	public var displacement:Vector3D = new Vector3D();
	public var contacts:Array<CollisionHit3D> = [];
	public var grounded:Bool = false;
	public var groundNormal:Vector3D;
	public var stepped:Bool = false;
	public var slopeLimited:Bool = false;
	public var hitCeiling:Bool = false;
	public var blocked:Bool = false;
	/** 滑动预算耗尽，未确认的剩余位移被舍弃。 */
	public var iterationLimited:Bool = false;
	/** 初始重叠未能在预算内解除，此次停止请求运动，保留已经完成的推出。 */
	public var stuck:Bool = false;
	public function new() {}
}
