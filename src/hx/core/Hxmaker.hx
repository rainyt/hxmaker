package hx.core;

import hx.display.Stage;

/**
 * 引擎核心入口类，负责初始化引擎和管理全局状态
 * 整个应用生命周期中，通常只需要一个引擎实例
 */
class Hxmaker {
	/**
	 * 引擎实例的内部存储
	 */
	private static var __engine:IEngine;

	/**
	 * 引擎对象，整个生命周期中，只需要一个引擎对象
	 * @return 当前引擎实例
	 */
	public static var engine(get, never):IEngine;

	/**
	 * 顶级视图舞台，作为所有UI元素的根容器
	 */
	public static var topView:Stage = new Stage();

	/**
	 * 获取当前引擎实例
	 * @return 当前引擎实例
	 */
	private static function get_engine():IEngine {
		return __engine;
	}

	/**
	 * 初始化引擎
	 * @param classes 引擎实现类
	 * @param stageWidth 舞台宽度，0表示使用默认宽度
	 * @param stageHeight 舞台高度，0表示使用默认高度
	 * @param cacheAsBitmap 是否开启缓存为位图，默认为false
	 * @param lockLandscape 是否锁定横屏模式，默认为false
	 * @return 初始化后的引擎实例
	 */
	public static function init<T:IEngine>(classes:Class<T>, stageWidth:Int, stageHeight:Int, cacheAsBitmap:Bool = false, lockLandscape:Bool = false):T {
		__engine = Type.createInstance(classes, []);
		__engine.init(stageWidth, stageHeight, lockLandscape);
		__engine.stages.push(topView);
		__engine.renderer.cacheAsBitmap = cacheAsBitmap;
		return cast __engine;
	}
}
