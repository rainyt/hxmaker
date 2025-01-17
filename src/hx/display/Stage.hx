package hx.display;

import hx.utils.SoundManager;
import hx.events.Event;
import hx.events.KeyboardEvent;

/**
 * 游戏引擎舞台
 */
class Stage extends Box {
	@:noCompletion private var __stageWidth:Float = 0;
	@:noCompletion private var __stageHeight:Float = 0;

	override function get_stage():Stage {
		return this;
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
	public function handleMouseEvent(event:hx.events.MouseEvent):Bool {
		var touchList = [];
		if (__hitTest(event.stageX, event.stageY, touchList)) {
			for (index => object in touchList) {
				if (object.parent != null && !object.parent.mouseChildren) {
					touchList.splice(index, touchList.length - index);
					break;
				}
			}
			var display:DisplayObject = touchList[touchList.length - 1];
			for (object in touchList) {
				event.target = display;
				object.dispatchEvent(event);
			}
			return true;
		} else {
			// 舞台要触发事件
			event.target = this;
			this.dispatchEvent(event);
		}
		return false;
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

	override function dispatchEvent(event:Event) {
		super.dispatchEvent(event);
		if (event.type == Event.RESIZE) {
			this.updateLayout();
		}
	}

	override function get_width():Float {
		return this.stageWidth;
	}

	override function get_height():Float {
		return this.stageHeight;
	}

	public function onActivate():Void {
		// 程序获得焦点
		this.dispatchEvent(new Event(Event.ACTIVATE));
		SoundManager.getInstance().resumeBGMSound();
	}

	public function onDeactivate():Void {
		// 程序失去焦点
		this.dispatchEvent(new Event(Event.DEACTIVATE));
		SoundManager.getInstance().stopAllSound();
	}
}
