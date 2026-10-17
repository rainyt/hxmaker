package;

import hx.core.HxmakerApplication;

/** 应用入口只负责初始化引擎和舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(Game, 1040, 800);
	}
}
