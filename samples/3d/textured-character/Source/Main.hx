package;

import hx.core.HxmakerApplication;

/** 应用入口只初始化 hxmaker；示例逻辑由舞台与场景管理。 */
class Main extends HxmakerApplication {
	public function new() {
		super();
		init(Game, 960, 820);
	}
}
