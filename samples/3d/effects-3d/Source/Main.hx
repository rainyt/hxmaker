package;

import hx.core.HxmakerApplication;

/** 应用入口统一通过 HxmakerApplication 初始化业务舞台。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(Game, 960, 640);
	}
}
