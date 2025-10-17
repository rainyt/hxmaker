package hx.utils;

import hx.display.ISceneExchangeEffect;
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

	/**
	 * 当前显示的场景
	 */
	public var currentScene(get, never):Scene;

	private function get_currentScene():Scene {
		if (scenes.length > 0) {
			return scenes[scenes.length - 1];
		}
		return null;
	}

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
	public function releaseScene(scene:Scene) {
		scene.dispose();
		var has = scenes.remove(scene);
		scene.parent?.removeChild(scene);
		// 如果仍然存在场景，则返回到之前的场景上
		if (has && scenes.length > 0) {
			var lastScene = scenes[scenes.length - 1];
			if (lastScene.parent == null)
				showScene(lastScene);
		}
		if (has) {
			scene.onReleaseEvent.call();
		}
	}

	/**
	 * 默认的场景切换效果
	 */
	public var defaultSceneExchangeEffect:Class<ISceneExchangeEffect>;

	/**
	 * 更换场景
	 * @param scene 
	 */
	public function replaceScene(scene:Scene, releaseOldScene:Bool = false) {
		if (scenes.length > 0) {
			var oldScene = scenes[scenes.length - 1];
			function removeScene():Void {
				if (releaseOldScene) {
					this.releaseScene(oldScene);
				} else {
					// 如果不释放，则简单移除场景
					oldScene.parent?.removeChild(oldScene);
				}
			}
			if (defaultSceneExchangeEffect == null) {
				showScene(scene);
				removeScene();
			} else {
				showScene(scene);
				var exchange:ISceneExchangeEffect = Type.createInstance(defaultSceneExchangeEffect, []);
				Hxmaker.topView.addChild(cast exchange);
				exchange.onReadyExchange(scene, () -> {
					removeScene();
					scene.visible = true;
				});
				scene.visible = false;
			}
		} else {
			showScene(scene);
		}
	}

	/**
	 * 展示场景
	 * @param scene 
	 */
	public function showScene(scene:Scene):Void {
		if (scenes.indexOf(scene) == -1)
			scenes.push(scene);
		Hxmaker.engine.stages[0].addChild(scene);
	}

	/**
	 * 返回上一个场景
	 */
	public function backScene(releaseOldScene:Bool = false):Void {
		if (scenes.length > 2) {
			var scene = scenes[scenes.length - 2];
			this.replaceScene(scene, releaseOldScene);
		}
	}
}
