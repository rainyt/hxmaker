package hx.display;

import hx.events.MouseEvent;
import hx.utils.SoundManager;
import hx.events.Event;
import hx.events.KeyboardEvent;

/**
 * 游戏引擎舞台
 */
class Stage extends Box {
	@:noCompletion private var __stageWidth:Float = 0;
	@:noCompletion private var __stageHeight:Float = 0;

	/**
	 * 舞台的焦点对象
	 */
	public var focus(get, set):DisplayObject;

	private static var __focus:DisplayObject;

	private function set_focus(value:DisplayObject):DisplayObject {
		__focus = value;
		return __focus;
	}

	private function get_focus():DisplayObject {
		return __focus;
	}

	/**
	 * 是否为自定义渲染，如果为自定义渲染，引擎则只生效触摸事件，但不会进行额外渲染
	 */
	public var customRender(default, set):Bool = false;

	private function set_customRender(value:Bool):Bool {
		this.customRender = value;
		return value;
	}

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

	private static var __overDisplayObject:DisplayObject;

	/**
	 * 触发鼠标事件
	 * @param event 
	 */
	public function handleMouseEvent(event:hx.events.MouseEvent, needHitTest:Bool):Bool {
		var touchList = [];
		if (needHitTest && __hitTest(event.stageX, event.stageY, touchList)) {
			for (index => object in touchList) {
				if (object.parent != null && !object.parent.mouseChildren) {
					touchList.splice(index, touchList.length - index);
					break;
				}
			}
			var display:DisplayObject = touchList[touchList.length - 1];

			if (event.type == MouseEvent.CLICK) {
				// 如果是一样的，则无需处理新的回调
				if (focus != display) {
					if (focus != null) {
						focus.dispatchEvent(new Event(Event.FOCUS_OUT, false, true));
					}
					focus = display;
					focus.dispatchEvent(new Event(Event.FOCUS_OVER, false, true));
				}
			}

			var i = touchList.length;
			while (i-- > 0) {
				var object = touchList[i];
				event.target = display;
				object.dispatchEvent(event);
			}
			if (event.type == MouseEvent.MOUSE_MOVE) {
				// 需要触发MOUSE_OVER和 MOUSE_OUT事件
				if (__overDisplayObject != display) {
					if (__overDisplayObject != null) {
						var event = new MouseEvent(MouseEvent.MOUSE_OUT, false, true);
						event.target = __overDisplayObject;
						__overDisplayObject.dispatchEvent(event);
						__overDisplayObject = null;
					}
					__overDisplayObject = display;
					var event = new MouseEvent(MouseEvent.MOUSE_OVER, false, true);
					event.target = __overDisplayObject;
					__overDisplayObject.dispatchEvent(event);
				}
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
		if (focus != null && focus.stage == this) {
			focus.dispatchEvent(event);
		} else {
			this.dispatchEvent(event);
		}
	}

	override function dispatchEvent(event:Event) {
		if (event.type == Event.RESIZE) {
			this.updateLayout();
		}
		super.dispatchEvent(event);
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
