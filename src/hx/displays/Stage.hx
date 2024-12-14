package hx.displays;

/**
 * 游戏引擎舞台
 */
class Stage extends DisplayObjectContainer {
	override function get_stage():Stage {
		return this;
	}
}
