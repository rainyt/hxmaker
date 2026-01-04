package hx.core;

import hx.display.Stage;

class Hxmaker {
	private static var __engine:IEngine;

	/**
	 * 引擎对象，整个生命周期中，只需要一个引擎对象
	 */
	public static var engine(get, never):IEngine;

	public static var topView:Stage = new Stage();

	private static function get_engine():IEngine {
		return __engine;
	}

	/**
	 * 初始化引擎
	 * @param classes 引擎类
	 * @param stageWidth 舞台宽度自适应
	 * @param stageHeight 舞台高度自适应
	 */
	public static function init<T:IEngine>(classes:Class<T>, stageWidth:Int, stageHeight:Int, cacheAsBitmap:Bool = false):T {
		__engine = Type.createInstance(classes, []);
		__engine.init(stageWidth, stageHeight);
		__engine.stages.push(topView);
		__engine.renderer.cacheAsBitmap = cacheAsBitmap;
		return cast __engine;
	}
}
