package hx.utils;

import hx.core.Hxmaker;
import hx.display.Scene;

/**
 * 场景管理器
 */
class SceneManager {
	private static var __instance:SceneManager;

	/**
	 * 场景列表
	 */
	public var scenes:Array<Scene> = [];

	public static function getInstance():SceneManager {
		if (__instance == null) {
			__instance = new SceneManager();
		}
		return __instance;
	}

	private function new() {}

	/**
	 * 释放场景
	 * @param scene 
	 */
	public function releaseScene(scene:Scene, showOldScene:Bool = true) {
		scene.dispose();
		scenes.remove(scene);
		scene.parent?.removeChild(scene);
		// 如果仍然存在场景，则返回到之前的场景上
		if (showOldScene && scenes.length > 0) {
			var lastScene = scenes[scenes.length - 1];
			showScene(lastScene);
		}
	}

	/**
	 * 更换场景
	 * @param scene 
	 */
	public function replaceScene(scene:Scene, releaseOldScene:Bool = false) {
		if (scenes.length > 0 && releaseOldScene) {
			var oldScene = scenes[scenes.length - 1];
			this.releaseScene(oldScene, false);
		}
		showScene(scene);
	}

	/**
	 * 展示场景
	 * @param scene 
	 */
	public function showScene(scene:Scene):Void {
		scenes.push(scene);
		Hxmaker.engine.stages[0].addChild(scene);
	}
}
