package;

import openfl.display.FPS;

/**
 * 使用`hxmaker`游戏引擎
 */
class Main extends hx.core.Engine {
	public function new() {
		super();
		this.stage.color = 0x404040;
		this.init(Game, 1920, 1080);
		var fps = new FPS(10, 10, 0xff0000);
		this.addChild(fps);
		fps.scaleX = fps.scaleY = 2;
	}
}
