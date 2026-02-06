package hx.display;

import haxe.Timer;
import hx.utils.KeyboardTools;
import hx.events.Keyboard;
import hx.events.MouseEvent;
import hx.utils.SoundManager;
import hx.events.Event;
import hx.events.KeyboardEvent;

/**
 * 游戏引擎舞台类，是所有显示对象的根容器
 * 负责处理鼠标、触摸和键盘事件，以及管理舞台状态
 */
class Stage extends Box {
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
		if (__focus != null) {
			__focus.dispatchEvent(new Event(Event.FOCUS_OUT, false, true));
		}
		__focus = value;
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
	public function handleMouseEvent(event:hx.events.MouseEvent, needHitTest:Bool):Bool {
		var touchList = [];
		if (needHitTest && __hitTest(event.stageX, event.stageY, touchList)) {
			for (index => object in touchList) {
				if (object is DisplayObjectContainer && !cast(object, DisplayObjectContainer).mouseChildren) {
					touchList.splice(index + 1, touchList.length - index - 1);
					break;
				}
			}
			var display:DisplayObject = touchList[touchList.length - 1];

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

			var i = touchList.length;
			while (i-- > 0) {
				var object = touchList[i];
				event.target = display;
				object.dispatchEvent(event);
			}
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
				var event = new MouseEvent(MouseEvent.MOUSE_LONG_CLICK, false, true);
				this.__currentMouseDownDisplay.dispatchEvent(event);
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
		if (focus != null && focus.stage != null && focus.stage == this) {
			focus.dispatchEvent(event);
		} else {
			this.dispatchEvent(event);
		}
	}

	/**
	 * 重写事件分发方法，处理舞台特定的事件
	 * @param event 要分发的事件对象
	 */
	override function dispatchEvent(event:Event) {
		if (event.type == Event.RESIZE) {
			this.updateLayout();
		}
		super.dispatchEvent(event);
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
}
