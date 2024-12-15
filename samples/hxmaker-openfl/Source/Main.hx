package;

import openfl.display.FPS;

/**
 * 使用`hxmaker`游戏引擎
 */
class Main extends hx.core.Engine {
	public function new() {
		super();
		this.init(Game, 1920, 1080);
		var fps = new FPS(10, 10, 0xff0000);
		this.addChild(fps);
	}
}
