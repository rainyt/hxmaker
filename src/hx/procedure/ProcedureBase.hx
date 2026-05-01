package hx.procedure;

/**
 * 流程基类，实现了 IProcedure 接口，提供各生命周期方法的空实现
 * 业务流程类继承此类后，只需覆写需要的方法即可
 */
class ProcedureBase implements IProcedure {
	public function new() {}

	/**
	 * 流程注册到管理器后调用一次，用于初始化资源
	 */
	public function onInit():Void {}

	/**
	 * 流程被切换到当前活动流程时调用
	 */
	public function onEnter():Void {}

	/**
	 * 流程处于活动状态时每帧调用
	 * @param dt 帧间隔时间（秒）
	 */
	public function onUpdate(dt:Float):Void {}

	/**
	 * 当前活动流程被切出时调用
	 */
	public function onLeave():Void {}

	/**
	 * 流程从管理器移除时调用，用于释放资源
	 */
	public function onDestroy():Void {}
}
