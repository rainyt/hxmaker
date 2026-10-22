package;

import hx.core.HxmakerApplication;

/** 应用入口只负责初始化，所有示例逻辑位于业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 1120, 820);
	}
}
