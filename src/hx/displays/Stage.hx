package hx.displays;

import hx.events.KeyboardEvent;

/**
 * 游戏引擎舞台
 */
class Stage extends DisplayObjectContainer {
	@:noCompletion private var __render:IRender;
	@:noCompletion private var __stageWidth:Float = 0;
	@:noCompletion private var __stageHeight:Float = 0;

	/**
	 * 获得当前渲染器
	 */
	public var renderer(get, never):IRender;

	private function get_renderer():IRender {
		return __render;
	}

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

	/**
	 * 触发鼠标事件
	 * @param event 
	 */
	public function handleMouseEvent(event:hx.events.MouseEvent):Void {
		var touchList = [];
		if (__hitTest(event.stageX, event.stageY, touchList)) {
			var display:DisplayObject = touchList[touchList.length - 1];
			for (object in touchList) {
				event.target = display;
				object.dispatchEvent(event);
			}
		} else {
			// 舞台要触发事件
			event.target = this;
			this.dispatchEvent(event);
		}
	}

	/**
	 * 触发触摸事件
	 * @param event 
	 */
	public function handleTouchEvent(event:hx.events.TouchEvent):Void {}

	/**
	 * 触发键盘事件
	 * @param event 
	 */
	public function handleKeyboardEvent(event:KeyboardEvent):Void {
		event.target = this;
		this.dispatchEvent(event);
	}
}
