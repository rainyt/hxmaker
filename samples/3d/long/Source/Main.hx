package;

import hx.core.HxmakerApplication;

/** 应用入口仅负责初始化 hxmaker。 */
class Main extends HxmakerApplication {
    public function new() {
        super();
        init(Game, 1100, 760);
    }
}
