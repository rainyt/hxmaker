package hx.core;

class Hxmaker {
	private static var __engine:IEngine;

	/**
	 * 引擎对象，整个生命周期中，只需要一个引擎对象
	 */
	public static var engine(get, never):IEngine;

	private static function get_engine():IEngine {
		return __engine;
	}

	/**
	 * 初始化引擎
	 * @param classes 引擎类
	 * @param stageWidth 舞台宽度自适应
	 * @param stageHeight 舞台高度自适应
	 */
	public static function init<T:IEngine>(classes:Class<T>, stageWidth:Int, stageHeight:Int):T {
		__engine = Type.createInstance(classes, []);
		__engine.init(stageWidth, stageHeight);
		return cast __engine;
	}
}
