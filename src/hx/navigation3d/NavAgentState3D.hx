package hx.navigation3d;

/** 路径跟随状态，由调用方用于 UI 或业务状态切换。 */
enum abstract NavAgentState3D(String) to String {
	/** 尚无目标或已显式停止。 */
	var IDLE = "idle";

	/** 正沿路径移动。 */
	var MOVING = "moving";

	/** 暂停水平寻路移动，重力仍在显式 update 时推进。 */
	var PAUSED = "paused";

	/** 已在水平和高度容差内到达。 */
	var ARRIVED = "arrived";

	/** 搜索失败或找不到安全的接入节点。 */
	var NO_PATH = "noPath";

	/** 物理运动持续无进展，停止本次路径。 */
	var BLOCKED = "blocked";
}
