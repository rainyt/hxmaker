package;

import hx.core.HxmakerApplication;

/** 应用入口仅负责初始化引擎与业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 960, 640);
	}
}
