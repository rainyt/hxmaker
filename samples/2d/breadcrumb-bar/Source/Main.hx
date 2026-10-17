package;

import hx.core.HxmakerApplication;

/** 应用入口只负责初始化业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 800, 600);
	}
}
