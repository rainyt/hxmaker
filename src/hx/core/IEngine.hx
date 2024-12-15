package hx.core;

import hx.displays.Stage;

/**
 * 引擎接口
 */
interface IEngine {
	/**
	 * 初始化引擎
	 * @param mainClass 
	 * @param stageWidth 
	 * @param stageHeight 
	 */
	public function init(mainClass:Class<Stage>, stageWidth:Int, stageHeight:Int):Void;
}
