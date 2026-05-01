package hx.procedure;

/**
 * 流程接口，定义单个流程的生命周期方法
 *
 * 每个流程有五个生命周期阶段：
 * - onInit：流程注册到管理器后调用一次，用于初始化
 * - onEnter：流程被切换到当前活动流程时调用
 * - onUpdate：流程处于活动状态时每帧调用
 * - onLeave：当前活动流程被切出时调用
 * - onDestroy：流程从管理器移除时调用，用于资源释放
 */
interface IProcedure {
	/**
	 * 流程注册到管理器后调用一次，用于初始化资源
	 */
	public function onInit():Void;

	/**
	 * 流程被切换到当前活动流程时调用
	 */
	public function onEnter():Void;

	/**
	 * 流程处于活动状态时每帧调用
	 * @param dt 帧间隔时间（秒）
	 */
	public function onUpdate(dt:Float):Void;

	/**
	 * 当前活动流程被切出时调用
	 */
	public function onLeave():Void;

	/**
	 * 流程从管理器移除时调用，用于释放资源
	 */
	public function onDestroy():Void;
}
