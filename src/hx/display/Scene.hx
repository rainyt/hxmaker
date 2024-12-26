package hx.display;

import hx.core.Hxmaker;

/**
 * 场景容器
 */
class Scene extends Box {
	override function get_width():Float {
		return Hxmaker.engine.stageWidth;
	}

	override function get_height():Float {
		return Hxmaker.engine.stageHeight;
	}
}
