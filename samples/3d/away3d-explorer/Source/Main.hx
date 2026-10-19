package;

import hx.core.HxmakerApplication;

/** 应用入口只初始化探索舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 1120, 760);
	}
}
