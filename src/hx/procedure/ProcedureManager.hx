package hx.procedure;

/**
 * 流程管理器，用于管理多个流程的注册、切换和生命周期调度
 *
 * 使用方式：
 * 1. 创建 IProcedure 实现类
 * 2. 通过 switchProcedure() 切换流程，未注册时会自动注册
 * 3. 也可手动 registerProcedure() 提前注册
 * 4. 在游戏主循环中调用 update() 驱动当前流程的 onUpdate
 *
 * 流程管理器与渲染/显示系统完全解耦，可独立使用。
 */
class ProcedureManager {
	/**
	 * 全局单例，方便跨模块访问
	 */
	public static var instance(get, never):ProcedureManager;

	private static var __instance:ProcedureManager;

	private static function get_instance():ProcedureManager {
		if (__instance == null) {
			__instance = new ProcedureManager();
		}
		return __instance;
	}

	/**
	 * 所有已注册的流程，以流程类全限定名为键（用于兼容 JS 目标）
	 */
	private var procedures:Map<String, IProcedure> = [];

	/**
	 * 当前活动的流程
	 */
	public var currentProcedure(get, null):IProcedure;

	/**
	 * 已注册的流程数量
	 */
	public var procedureCount(get, null):Int;

	private function get_currentProcedure():IProcedure {
		return currentProcedure;
	}

	private function get_procedureCount():Int {
		var count = 0;
		for (_ in procedures)
			count++;
		return count;
	}

	public function new() {}

	/**
	 * 注册一个流程到管理器
	 * 注册后会立即调用流程的 onInit() 方法
	 * @param procedure 要注册的流程实例
	 */
	public function registerProcedure<T:IProcedure>(procedure:T):T {
		var key = Type.getClassName(Type.getClass(procedure));
		if (procedures.exists(key)) {
			throw '流程 $key 已经注册';
		}
		procedures.set(key, procedure);
		procedure.onInit();
		return procedure;
	}

	/**
	 * 切换到指定类型的流程
	 * 如果目标流程未注册，会自动通过 Type.createInstance 创建实例并注册
	 * 如果当前有活动流程，会先调用其 onLeave()，再调用目标流程的 onEnter()
	 * @param clazz 目标流程的类
	 * @return 切换后的流程实例
	 */
	public function switchProcedure<T:IProcedure>(clazz:Class<T>):T {
		var key = Type.getClassName(clazz);
		var target:IProcedure = procedures.get(key);
		if (target == null) {
			target = Type.createInstance(clazz, []);
			procedures.set(key, target);
			target.onInit();
		}

		// 如果目标流程就是当前流程，不执行切换
		if (currentProcedure == target) {
			return cast target;
		}

		// 离开当前流程
		if (currentProcedure != null) {
			currentProcedure.onLeave();
		}

		// 进入目标流程
		currentProcedure = target;
		target.onEnter();

		return cast target;
	}

	/**
	 * 获取已注册的指定类型流程
	 * @param clazz 流程的类
	 * @return 流程实例，未注册时返回 null
	 */
	public function getProcedure<T:IProcedure>(clazz:Class<T>):T {
		return cast procedures.get(Type.getClassName(clazz));
	}

	/**
	 * 移除指定类型的流程
	 * 移除前会调用 onDestroy()，如果是当前活动流程则先调用 onLeave()
	 * @param clazz 要移除的流程类
	 * @return 是否成功移除
	 */
	public function removeProcedure<T:IProcedure>(clazz:Class<T>):Bool {
		var key = Type.getClassName(clazz);
		var target = procedures.get(key);
		if (target == null) {
			return false;
		}

		if (currentProcedure == target) {
			currentProcedure.onLeave();
			currentProcedure = null;
		}

		target.onDestroy();
		return procedures.remove(key);
	}

	/**
	 * 驱动当前活动流程的帧更新
	 * 应放在游戏主循环中每帧调用
	 * @param dt 帧间隔时间（秒）
	 */
	public function update(dt:Float):Void {
		if (currentProcedure != null) {
			currentProcedure.onUpdate(dt);
		}
	}

	/**
	 * 销毁管理器，依次退出当前流程并销毁所有已注册流程
	 */
	public function destroy():Void {
		if (currentProcedure != null) {
			currentProcedure.onLeave();
			currentProcedure = null;
		}

		for (proc in procedures) {
			proc.onDestroy();
		}
		procedures.clear();
	}
}
