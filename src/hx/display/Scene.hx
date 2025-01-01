package hx.display;

import hx.utils.SceneManager;
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

	public function releaseScene():Void {
		SceneManager.getInstance().releaseScene(this);
	}

	public function replaceScene(scene:Scene, releaseOldScene:Bool = false):Void {
		SceneManager.getInstance().replaceScene(scene, releaseOldScene);
	}
}
