package;

import hx.core.HxmakerApplication;

/** 启动类只负责初始化业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 1100, 760);
	}
}
