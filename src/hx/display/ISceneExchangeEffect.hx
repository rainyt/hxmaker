package hx.display;

interface ISceneExchangeEffect {
	/**
	 * 准备切换到当前场景
	 * @param scene 
	 */
	public function onReadyExchange(scene:Scene, onLoaded:Void->Void):Void;
}
