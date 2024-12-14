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
@:access(hx.displays.DisplayObject)
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

	public function clear():Void {
		// 清理舞台
		__stage.removeChildren();
	}

	public function renderDisplayObjectContainer(container:DisplayObjectContainer) {
		for (object in container.children) {
			if (object is Image) {
				renderImage(cast object);
			} else if (object is DisplayObjectContainer) {
				renderDisplayObjectContainer(cast object);
			}
		}
	}

	/**
	 * 渲染Image对象
	 * @param image 
	 */
	public function renderImage(image:Image) {
		var bitmap:Bitmap = new Bitmap(image.data.data.getTexture());
		__stage.addChild(bitmap);
		bitmap.x = image.__worldX;
		bitmap.y = image.__worldY;
	}

	public function endFill():Void {}
}
