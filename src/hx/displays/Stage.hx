package hx.displays;

/**
 * 游戏引擎舞台
 */
class Stage extends DisplayObjectContainer {
	@:noCompletion private var __render:IRender;
	@:noCompletion private var __stageWidth:Float = 0;
	@:noCompletion private var __stageHeight:Float = 0;

	override function get_stage():Stage {
		return this;
	}

	/**
	 * 渲染舞台，当开始对舞台对象进行渲染时，会对图片进行一个性能优化处理
	 */
	public function render():Void {
		if (this.__dirty) {
			this.__updateTransform(this);
			__render.clear();
			__render.renderDisplayObjectContainer(this);
			__render.endFill();
			this.__dirty = false;
		}
	}

	/**
	 * 获得舞台宽度
	 */
	public var stageWidth(get, never):Float;

	private function get_stageWidth():Float {
		return __stageWidth;
	}

	/**
	 * 获得舞台高度
	 */
	public var stageHeight(get, never):Float;

	private function get_stageHeight():Float {
		return __stageHeight;
	}

	public function new() {
		super();
	}
}
