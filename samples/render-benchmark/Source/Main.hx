package;

import hx.core.HxmakerApplication;

/** 入口只负责初始化；基线配置、场景及采样位于业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 960, 640);
	}
}
