package hx.displays;

/**
 * 游戏引擎舞台
 */
class Stage extends DisplayObjectContainer {
	@:noCompletion private var __render:IRender;

	override function get_stage():Stage {
		return this;
	}

	/**
	 * 渲染舞台，当开始对舞台对象进行渲染时，会对图片进行一个性能优化处理
	 */
	public function render():Void {
		__render.render(this);
	}
}
