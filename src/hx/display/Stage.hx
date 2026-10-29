package hx.display;

import hx.core.Hxmaker;
import hx.core.Engine;
import haxe.Timer;
import hx.utils.KeyboardTools;
import hx.events.Keyboard;
import hx.events.MouseEvent;
import hx.utils.SoundManager;
import hx.events.Event;
import hx.events.KeyboardEvent;
import hx.events.TouchEvent;

/**
 * 游戏引擎舞台类，是所有显示对象的根容器
 * 负责处理鼠标、触摸和键盘事件，以及管理舞台状态
 */
class Stage extends Box {
	/** 当前舞台已经打开的菜单；浮层遵守引擎已有的舞台叠放顺序。 */
	public var openedContextMenu(default, null):ContextMenu;
	private var __contextMenuEvents:EventDispatcher = new ContextMenuEventDispatcher();
	private var __pointerCaptureListeners:Array<MouseEvent->Void> = [];
	/** 捕获期间观察舞台原始指针事件，早于 UI 冒泡；监听不得改写或取消源事件。 */
	public function addPointerCaptureListener(listener:MouseEvent->Void):Void {
		if (listener == null || isDisposed) throw "不能添加无效的指针捕获监听";
		if (__pointerCaptureListeners.indexOf(listener) < 0) __pointerCaptureListeners.push(listener);
	}
	public function removePointerCaptureListener(listener:MouseEvent->Void):Void { __pointerCaptureListeners.remove(listener); }
	/**
	 * 舞台宽度的内部存储
	 */
	@:noCompletion private var __stageWidth:Float = 0;

	/**
	 * 舞台高度的内部存储
	 */
	@:noCompletion private var __stageHeight:Float = 0;

	/**
	 * 舞台的焦点对象
	 * @return 当前获得焦点的显示对象
	 */
	public var focus(get, set):DisplayObject;

	/**
	 * 全局焦点对象的静态存储
	 */
	private static var __focus:DisplayObject;

	/**
	 * 设置舞台焦点对象
	 * @param value 要设置为焦点的显示对象
	 * @return 设置后的焦点对象
	 */
	private function set_focus(value:DisplayObject):DisplayObject {
		if (__focus == value)
			return value;
		if (__focus != null) {
			__focus.dispatchEvent(new Event(Event.FOCUS_OUT, false, true));
		}
		__focus = value;
		if (__focus != null)
			__focus.dispatchEvent(new Event(Event.FOCUS_OVER, false, true));
		return __focus;
	}

	/**
	 * 获取当前焦点对象
	 * @return 当前获得焦点的显示对象
	 */
	private function get_focus():DisplayObject {
		return __focus;
	}

	/**
	 * 从当前焦点切到下一个可用对象；reverse 为 true 时反向切换，首尾循环。
	 * 没有有效的接口焦点时不查询显示树，也不主动选中第一个对象。
	 * 返回是否接管了本次切换；仅有当前对象时保留焦点并返回 true。
	 */
	public function focusNext(reverse:Bool = false):Bool {
		var current = focus;
		if (current == null || current.stage != this || current.isDisposed || !(current is ITabFocusable))
			return false;
		var focusable:ITabFocusable = cast current;
		if (!focusable.tabEnabled || focusable.tabIndex < 0)
			return false;
		var candidates:Array<{display:DisplayObject, tabIndex:Int, order:Int}> = [];
		__collectTabFocus(this, candidates);
		candidates.sort((a, b) -> a.tabIndex == b.tabIndex ? a.order - b.order : a.tabIndex < b.tabIndex ? -1 : 1);
		var index = -1;
		for (i in 0...candidates.length) {
			if (candidates[i].display == current) {
				index = i;
				break;
			}
		}
		if (index < 0)
			return false;
		var next = candidates[(index + (reverse ? candidates.length - 1 : 1)) % candidates.length].display;
		if (next != current) {
			focus = next;
			// 焦点事件允许业务再次转移焦点，此时不激活已经失焦的对象。
			if (focus == next && !next.isDisposed && next.stage == this)
				cast(next, ITabFocusable).focus();
		}
		return true;
	}

	private function __collectTabFocus(object:DisplayObject, candidates:Array<{display:DisplayObject, tabIndex:Int, order:Int}>):Void {
		if (object.isDisposed || !object.visible || !object.mouseEnabled || object.alpha <= 0 || object.stage != this)
			return;
		if (object is ITabFocusable) {
			var focusable:ITabFocusable = cast object;
			if (focusable.tabEnabled && focusable.tabIndex >= 0)
				candidates.push({display: object, tabIndex: focusable.tabIndex, order: candidates.length});
		}
		if (object is DisplayObjectContainer) {
			var container = cast(object, DisplayObjectContainer);
			if (container.mouseChildren)
				for (child in container.children)
					__collectTabFocus(child, candidates);
		}
	}

	/**
	 * 是否为自定义渲染，如果为自定义渲染，引擎则只生效触摸事件，但不会进行额外渲染
	 */
	public var customRender(default, set):Bool = false;

	/**
	 * 设置是否使用自定义渲染
	 * @param value 是否开启自定义渲染
	 * @return 设置后的值
	 */
	private function set_customRender(value:Bool):Bool {
		this.customRender = value;
		return value;
	}

	/**
	 * 重写获取舞台方法，返回自身
	 * @return 当前舞台实例
	 */
	override function get_stage():Stage {
		return this;
	}

	/**
	 * 获得舞台宽度
	 * @return 舞台的当前宽度
	 */
	public var stageWidth(get, never):Float;

	/**
	 * 获取舞台宽度的内部实现
	 * @return 舞台的当前宽度
	 */
	private function get_stageWidth():Float {
		return __stageWidth;
	}

	/**
	 * 获得舞台高度
	 * @return 舞台的当前高度
	 */
	public var stageHeight(get, never):Float;

	/**
	 * 获取舞台高度的内部实现
	 * @return 舞台的当前高度
	 */
	private function get_stageHeight():Float {
		return __stageHeight;
	}

	/**
	 * 创建新的舞台实例
	 */
	public function new() {
		super();
		#if (html5 && !wechat)
		hx.utils.inputs.HTML5FocusNavigation.init();
		#end
	}

	/**
	 * 当前鼠标悬停的显示对象
	 */
	private static var __overDisplayObject:DisplayObject;

	/**
	 * 舞台X坐标
	 */
	private var __stageX:Float = 0;

	/**
	 * 舞台Y坐标
	 */
	private var __stageY:Float = 0;

	/**
	 * 上一次点击的时间戳
	 */
	private var __lastClickTime:Float = 0;

	/**
	 * 当前鼠标按下的显示对象
	 */
	private var __currentMouseDownDisplay:DisplayObject;

	/**
	 * 鼠标按下的持续时间
	 */
	private var __mouseDownDt:Float = 0.;

	/**
	 * 触发鼠标事件
	 * @param event 鼠标事件对象
	 * @param needHitTest 是否需要进行命中测试
	 * @return 是否成功处理了鼠标事件
	 */
	public function handleMouseEvent(event:hx.events.MouseEvent, needHitTest:Bool, dispatch:Bool = true):Bool {
		// 已开始的拖动即使跨过会消费事件的二维 UI，也必须收到移动和抬起。
		if (dispatch && __pointerCaptureListeners.length > 0
			&& (event.type == MouseEvent.MOUSE_DOWN || event.type == MouseEvent.MOUSE_MOVE || event.type == MouseEvent.MOUSE_UP
				|| event.type == TouchEvent.TOUCH_BEGIN || event.type == TouchEvent.TOUCH_MOVE || event.type == TouchEvent.TOUCH_END || event.type == TouchEvent.TOUCH_CANCEL))
			for (listener in __pointerCaptureListeners.copy()) listener(event);
		if (!needHitTest) {
			// 上层舞台已经命中时，本舞台只接收原有舞台通知，不打开菜单。
			event.target = this;
			this.dispatchEvent(event);
			return false;
		}
		var touchList = [];
		if (needHitTest && __hitTest(event.stageX, event.stageY, touchList)) {
			for (index => object in touchList) {
				if (object is DisplayObjectContainer && !cast(object, DisplayObjectContainer).mouseChildren) {
					touchList.splice(index + 1, touchList.length - index - 1);
					break;
				}
			}
			return __dispatchMouseEvent(touchList, event, dispatch);
		} else {
			// 无可触摸的情况下，应该触发stage的事件
			event.target = this;
			if (dispatch)
				__contextMenuEvents.dispatchEvent(event);
			this.dispatchEvent(event);
			if (dispatch && event.type == MouseEvent.RIGHT_CLICK)
				__openContextMenu(this, event);
		}
		return dispatch && event.type == MouseEvent.RIGHT_CLICK && event.contextMenuHandled;
	}

	private function __dispatchMouseEvent(touchList:Array<DisplayObject>, event:MouseEvent, dispatch:Bool = true):Bool {
		var display:DisplayObject = touchList[touchList.length - 1];
		var menuOwner = event.type == MouseEvent.RIGHT_CLICK ? __findContextMenuOwner(display) : null;
		if (event.type == MouseEvent.RIGHT_CLICK && menuOwner == null && openedContextMenu != null && @:privateAccess openedContextMenu.containsTarget(display))
			event.contextMenuHandled = true;
		event.contextMenuOwner = menuOwner;
		event.target = display;
		if (dispatch)
			__contextMenuEvents.dispatchEvent(event);

		if (event.type == MouseEvent.MOUSE_MOVE) {
			this.__mouseDownDt = 0;
		} else if (event.type == MouseEvent.MOUSE_DOWN) {
			this.__currentMouseDownDisplay = display;
			this.__mouseDownDt = 0;
			this.focus = display;
		} else if (event.type == MouseEvent.MOUSE_UP) {
			this.__currentMouseDownDisplay = null;
		}

		if (event.type == MouseEvent.CLICK) {
			if (focus == display) {
				if (Timer.stamp() - __lastClickTime < 0.3) {
					var event = new MouseEvent(MouseEvent.DOUBLE_CLICK, false, true);
					event.target = focus;
					if (dispatch)
						focus.dispatchEvent(event);
					__lastClickTime = 0;
				} else
					__lastClickTime = Timer.stamp();
			} else {
				return false;
			}
		}

		__stageX = event.stageX;
		__stageY = event.stageY;

		if (dispatch) {
			var i = touchList.length;
			while (i-- > 0) {
				var object = touchList[i];
				event.target = display;
				object.dispatchEvent(event);
				if (event.isDefaultPrevented) {
					if (event.type != MouseEvent.RIGHT_CLICK)
						return true;
					break;
				}
			}
			if (event.type == MouseEvent.RIGHT_CLICK)
				__openContextMenu(menuOwner, event);

			if (event.type == MouseEvent.MOUSE_MOVE) {
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
			event.target = this;
			this.dispatchEvent(event);
		}
		return false;
	}

	/**
	 * 每帧更新舞台状态
	 * @param dt 时间间隔，单位为秒
	 */
	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (this.__currentMouseDownDisplay != null) {
			__mouseDownDt += dt;
			if (this.__mouseDownDt > 0.5) {
				var touchList = [];
				this.__hitTest(this.__stageX, this.__stageY, touchList);
				for (index => object in touchList) {
					if (object is DisplayObjectContainer && !cast(object, DisplayObjectContainer).mouseChildren) {
						touchList.splice(index + 1, touchList.length - index - 1);
						break;
					}
				}
				if (touchList.length > 0 && touchList[touchList.length - 1] == this.__currentMouseDownDisplay) {
					var event = new MouseEvent(MouseEvent.MOUSE_LONG_CLICK, false, true);
					event.stageX = this.__stageX;
					event.stageY = this.__stageY;
					this.__currentMouseDownDisplay.dispatchEvent(event);
				}
			}
		}
	}

	/**
	 * 触发触摸事件
	 * @param event 触摸事件对象
	 */
	public function handleTouchEvent(event:hx.events.TouchEvent):Void {}

	/**
	 * 触发键盘事件
	 * @param event 键盘事件对象
	 */
	public function handleKeyboardEvent(event:KeyboardEvent):Void {
		event.target = this;
		// 菜单的 Esc 优先于输入框；其他按键仍按原有焦点规则分发。
		__contextMenuEvents.dispatchEvent(event);
		if (event.isDefaultPrevented)
			return;
		var current = focus;
		if (focus != null && focus.stage != null && focus.stage == this) {
			focus.dispatchEvent(event);
		} else {
			this.dispatchEvent(event);
		}
		// 先让当前焦点处理或取消按键；只有原焦点仍有效时才执行默认切换。
		if (!event.isDefaultPrevented && event.type == KeyboardEvent.KEY_DOWN && event.keyCode == Keyboard.TAB
			&& !event.isComposing && !event.ctrlKey && !event.altKey && !event.metaKey
			&& !KeyboardTools.isKeyDown(Keyboard.CONTROL) && !KeyboardTools.isKeyDown(Keyboard.ALTERNATE)
			&& !KeyboardTools.isKeyDown(Keyboard.COMMAND) && current != null && focus == current && current.stage == this
			#if (html5 && !wechat)
			&& !hx.utils.inputs.HTML5FocusNavigation.isExternalEditorFocused()
			#end
			&& focusNext(event.shiftKey || KeyboardTools.isKeyDown(Keyboard.SHIFT)))
			event.preventDefault();
	}

	/**
	 * 重写事件分发方法，处理舞台特定的事件
	 * @param event 要分发的事件对象
	 */
	override function dispatchEvent(event:Event) {
		if (event.type == Event.RESIZE || event.type == Event.DEACTIVATE)
			__contextMenuEvents.dispatchEvent(event);
		if (event.type == Event.RESIZE) {
			this.updateLayout();
		}
		super.dispatchEvent(event);
	}

	private function __findContextMenuOwner(target:DisplayObject):DisplayObject {
		var current = target;
		while (current != null) {
			if (current.contextMenu != null)
				return current;
			current = current.parent;
		}
		return null;
	}

	private function __openContextMenu(owner:DisplayObject, event:MouseEvent):Void {
		if (owner == null || !owner.mouseEnabled || !owner.visible || owner.stage != this || owner.contextMenu == null || event.contextMenuHandled)
			return;
		event.contextMenuHandled = true;
		@:privateAccess owner.contextMenu.open(owner, cast event.target, event.stageX, event.stageY);
	}

	/** 后端可在原生 contextmenu 先于 RIGHT_CLICK 到达时查询接管状态，不触发选择或菜单事件。 */
	public function hasContextMenuAt(stageX:Float, stageY:Float):Bool {
		if (!mouseEnabled || !visible)
			return false;
		var path:Array<DisplayObject> = [];
		if (!__hitTest(stageX, stageY, path))
			return contextMenu != null;
		var target = path[path.length - 1];
		for (object in path) {
			if (object is DisplayObjectContainer && !cast(object, DisplayObjectContainer).mouseChildren) {
				target = object;
				break;
			}
		}
		if (openedContextMenu != null && @:privateAccess openedContextMenu.containsTarget(target))
			return true;
		return __findContextMenuOwner(target) != null;
	}

	override public function dispose():Void {
		__pointerCaptureListeners = [];
		if (openedContextMenu != null)
			openedContextMenu.close();
		if (focus != null && focus.stage == this)
			focus = null;
		super.dispose();
	}

	/**
	 * 重写获取宽度方法，返回舞台宽度
	 * @return 舞台的当前宽度
	 */
	override function get_width():Float {
		return this.stageWidth;
	}

	/**
	 * 重写获取高度方法，返回舞台高度
	 * @return 舞台的当前高度
	 */
	override function get_height():Float {
		return this.stageHeight;
	}

	/**
	 * 程序获得焦点时调用
	 */
	public function onActivate():Void {
		this.dispatchEvent(new Event(Event.ACTIVATE));
		SoundManager.getInstance().resumeBGMSound();
	}

	/**
	 * 程序失去焦点时调用
	 */
	public function onDeactivate():Void {
		this.dispatchEvent(new Event(Event.DEACTIVATE));
		SoundManager.getInstance().stopAllSound();
	}

	override public function toString():String {
		return "[" + Type.getClassName(Type.getClass(this)) + " Stage " + Hxmaker.engine.stages.indexOf(this) + "]";
	}
}

/** 菜单打开期间使用的舞台输入侦听器，优先于焦点及冒泡处理。 */
private class ContextMenuEventDispatcher extends EventDispatcher {
	public function new() {
		#if hxmaker_unity
		super();
		#end
	}
}
