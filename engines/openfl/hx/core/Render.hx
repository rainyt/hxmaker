package hx.core;

import hx.displays.Image;
import hx.displays.DisplayObjectContainer;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import hx.displays.Stage;
import hx.displays.IRender;

/**
 * OpenFL的渲染器支持
 */
class Render implements IRender {
	/**
	 * 在OpenFL中渲染的舞台对象
	 */
	@:noCompletion private var __stage:Sprite = new Sprite();

	/**
	 * 游戏引擎对象
	 */
	public var engine:Engine;

	public function new(engine:Engine) {
		this.engine = engine;
		this.engine.addChild(__stage);
	}

	public function render(container:DisplayObjectContainer) {
		// TODO 该怎么渲染呢？
		// 清理舞台
		__stage.removeChildren();
		// 重新绘制开始
		for (object in container.children) {
			if (object is Image) {
				renderImage(cast object);
			}
		}
	}

	/**
	 * 渲染Image对象
	 * @param image 
	 */
	inline private function renderImage(image:Image) {
		var bitmap:Bitmap = new Bitmap(image.data.data.getTexture());
		__stage.addChild(bitmap);
	}
}
