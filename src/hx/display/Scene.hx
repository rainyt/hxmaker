package hx.display;

import hx.events.Event;
import hx.utils.SceneManager;
import hx.core.Hxmaker;

/**
 * 场景容器
 */
class Scene extends Box {
	private var __bg:Quad;

	/**
	 * 释放场景事件
	 */
	public var onReleaseEvent:FunctionListener = new FunctionListener();

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

	public function new() {
		super();
		__bg = new Quad(1, 1, 0xff0000);
		__bg.alpha = 0.;
		this.addChild(__bg);
	}

	override function updateLayout() {
		super.updateLayout();
		if (this.stage != null) {
			__bg.width = this.stage.width;
			__bg.height = this.stage.height;
		}
	}
}
