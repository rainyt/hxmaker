package hx.collision3d;

import hx.geom.Vector3D;

/** 一次显式运动的结果；位移包含脱离初始重叠与向下贴地修正。 */
class CharacterMoveResult3D {
	/** 最终世界位移，包含重叠推出、滑动、跨步与贴地修正。 */
	public var displacement:Vector3D = new Vector3D();

	/** 本次运动记录的接触列表，包含碰撞及落脚支撑。 */
	public var contacts:Array<CollisionHit3D> = [];

	/** 运动结束后是否获得可行走支撑。 */
	public var grounded:Bool = false;

	/** 支撑表面的世界法线；未接地时为 null。 */
	public var groundNormal:Vector3D;

	/** 是否成功执行一次升起、前进与落脚的跨步。 */
	public var stepped:Bool = false;

	/** 是否因坡度超过允许值而限制上坡运动。 */
	public var slopeLimited:Bool = false;

	/** 是否命中足以阻断向上运动的顶面。 */
	public var hitCeiling:Bool = false;

	/** 本次是否遇到接触阻挡；即使滑动后仍有进展也可能为 true。 */
	public var blocked:Bool = false;

	/** 滑动预算耗尽，未确认的剩余位移被舍弃。 */
	public var iterationLimited:Bool = false;

	/** 初始重叠未能在预算内解除，此次停止请求运动，保留已经完成的推出。 */
	public var stuck:Bool = false;

	/** 创建空运动结果，所有状态初始为 false。 */
	public function new() {}
}
