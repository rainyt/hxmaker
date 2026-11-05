package;

/** 启动类只初始化业务舞台，验证逻辑全部由舞台管理。 */
class Main extends hx.core.HxmakerApplication {
	public function new() {
		super();
		init(GameStage, 960, 640);
	}
}
