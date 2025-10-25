package hx.display;

import hx.events.Event;
import hx.events.TouchEvent;
import hx.display.DisplayObject;
import hx.geom.Point;
import hx.events.MouseEvent;

/**
 * 虚拟移动按键，可用于在手机上模拟人物的移动、方向等操作。
 */
@:keep
class VirtualTouchKey extends Box {
	/**
	 * 虚拟按键可点击的操作有效区域半径
	 */
	public var virtualTouchRadius:Int = 300;

	/**
	 * 是否固定滑动的区域点，默认为`fales`，需要时，请设置为`true`
	 */
	public var fixedOrignPoint:Bool = false;

	/**
	 * 移动时，原点最大半径
	 */
	public var virtualTouchOrginMaxRadius:Int = 400;

	/**
	 * 虚拟按键可点击的最大半径
	 */
	public var virtualTouchMaxRadius:Int = 600;

	/**
	 * 是否正在按下虚拟按键实现
	 */
	public var isTouchVirtualKey(get, never):Bool;

	private var _isAutoListener:Bool = false;

	private var _touchEvent:Bool = false;

	/**
	 * 是否一开始点击的位置为圆心
	 */
	public var beginOrginTouch:Bool = false;

	/**
	 * 构造一个虚拟按键计算模块
	 * @param isAutoListener 是否自动侦听触摸，默认为true
	 */
	public function new(isAutoListener:Bool = true, touchEvent:Bool = false) {
		super();
		_isAutoListener = isAutoListener;
		_touchEvent = touchEvent;
		this.width = this.height = 1;
	}

	private function get_isTouchVirtualKey():Bool {
		return _down;
	}

	/**
	 * 当前按键的虚拟角度
	 */
	public var virtualRotation(get, never):Float;

	public function get_virtualRotation():Float {
		return hx.geom.Point.rotationByFloat(_orignPos.x, _orignPos.y, _touchPos.x, _touchPos.y);
	}

	#if !jsapi
	override function onAddToStage() {
		super.onAddToStage();
		if (_isAutoListener) {
			if (_touchEvent) {
				stage.addEventListener(TouchEvent.TOUCH_BEGIN, onKeyMouseDown);
				stage.addEventListener(TouchEvent.TOUCH_MOVE, onKeyMouseMove);
				stage.addEventListener(TouchEvent.TOUCH_END, onKeyMouseUp);
			} else {
				stage.addEventListener(MouseEvent.MOUSE_DOWN, onKeyMouseDown);
				stage.addEventListener(MouseEvent.MOUSE_MOVE, onKeyMouseMove);
				stage.addEventListener(MouseEvent.MOUSE_UP, onKeyMouseUp);
			}
		}
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		if (_isAutoListener) {
			if (_touchEvent) {
				stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onKeyMouseDown);
				stage.removeEventListener(TouchEvent.TOUCH_MOVE, onKeyMouseMove);
				stage.removeEventListener(TouchEvent.TOUCH_END, onKeyMouseUp);
			} else {
				stage.removeEventListener(MouseEvent.MOUSE_DOWN, onKeyMouseDown);
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onKeyMouseMove);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onKeyMouseUp);
			}
		}
	}
	#end

	/**
	 * 拖动背景
	 */
	public var virtualTouchBGDisplay:DisplayObject;

	/**
	 * 拖动对象
	 */
	public var virtualTouchDisplay:DisplayObject;

	/**
	 * 是否需要检查原点半径，当符合半径外时，则不能使用原点，而是使用计算后的点
	 */
	public var needCheckVirtualTouchRadiusToOrginPoint:Bool = false;

	/**
	 * 当虚拟键按下触发侦听，返回值是弧度，但返回的是null时，则为松开按键
	 */
	public var onVirtualUpdate:Null<Float>->Void;

	/**
	 * 是否点下
	 */
	private var _down:Bool = false;

	/**
	 * 最开始按下的位置
	 */
	private var _beginPos:Point = new Point();

	/**
	 * 获取当前按下的坐标
	 */
	public var touchPos(get, never):Point;

	/**
	 * 获取当前触摸的影响力，可用于快走、慢走等逻辑判断，值在0-1之间
	 */
	public var touchInfluence(get, never):Float;

	private function get_touchInfluence():Float {
		var len = Point.distance(_touchPos, _orignPos);
		return Math.min(len / virtualTouchRadius, 1);
	}

	private function get_touchPos():Point {
		return _touchPos;
	}

	/**
	 * 当前点击点的位置
	 */
	private var _touchPos:Point = new Point();

	/**
	 * 用于计算的0,0原点
	 */
	private var _mathPos:Point = new Point();

	/**
	 * 获取当前按键的原点，原点会根据实际点击区域发生变化
	 */
	public var orignPos(get, never):Point;

	private function get_orignPos():Point {
		return _orignPos;
	}

	/**
	 * 原点，会根据距离重新计算，否则默认在0,0
	 */
	private var _orignPos:Point = new Point();

	private var _mouseX:Float;
	private var _mouseY:Float;

	public function onVirtualTouchDown(mouseX:Float, mouseY:Float):Void {
		_mouseX = mouseX;
		_mouseY = mouseY;
		onKeyMouseDown(null);
	}

	public function onVirtualTouchEnd(mouseX:Float, mouseY:Float):Void {
		_mouseX = mouseX;
		_mouseY = mouseY;
		onKeyMouseUp(null);
	}

	public function onVirtualTouchMove(mouseX:Float, mouseY:Float):Void {
		_mouseX = mouseX;
		_mouseY = mouseY;
		onKeyMouseMove(null);
	}

	private var _touchEventId:Int = -1;

	public function getTouchEventId():Int {
		return _touchEventId;
	}

	private function onKeyMouseDown(e:#if jsapi Dynamic #else Event #end):Void {
		if (e.target is Button) {
			return;
		}
		if (_touchEvent && _touchEventId != -1)
			return;
		if (e != null) {
			_mouseX = this.touchX;
			_mouseY = this.touchY;
			if (_touchEvent) {
				_touchEventId = cast(e, TouchEvent).touchPointID;
			}
		}
		_beginPos.x = _mouseX;
		_beginPos.y = _mouseY;
		_touchPos.x = _beginPos.x;
		_touchPos.y = _beginPos.y;
		if (beginOrginTouch) {
			// 如果点击的位置没有超出原点半径时，则以中间点处理
			if (needCheckVirtualTouchRadiusToOrginPoint) {
				var len = Point.distance(_touchPos, _orignPos);
				if (len < virtualTouchMaxRadius - virtualTouchRadius * 3) {
					_orignPos.x = _beginPos.x;
					_orignPos.y = _beginPos.y;
				} else {
					_orignPos.x = 0;
					_orignPos.y = 0;
				}
			} else {
				_orignPos.x = _beginPos.x;
				_orignPos.y = _beginPos.y;
			}
		} else {
			_orignPos.x = 0;
			_orignPos.y = 0;
		}
		if (Point.distance(_mathPos, _beginPos) < virtualTouchMaxRadius) {
			if (onCheckCanTouch(_beginPos)) {
				_down = true;
				onKeyMouseMove(e);
			}
		}
	}

	/**
	 * 可重写它实现自定义可触摸逻辑
	 * @param pos 
	 * @return Bool
	 */
	dynamic public function onCheckCanTouch(pos:Point):Bool {
		return true;
	}

	private function onKeyMouseMove(e:#if jsapi Dynamic #else Event #end):Void {
		if (!_down)
			return;
		if (_touchEvent) {
			if (_touchEventId != cast(e, TouchEvent).touchPointID)
				return;
		}
		if (e != null) {
			_mouseX = this.touchX;
			_mouseY = this.touchY;
		}
		if (_down) {
			_touchPos.x = this._mouseX;
			_touchPos.y = this._mouseY;
			resetVirtualTouchDisplay();
		}
	}

	private function onKeyMouseUp(e:#if jsapi Dynamic #else Event #end):Void {
		if (e != null) {
			_mouseX = this.touchX;
			_mouseY = this.touchY;
		}
		if (_touchEvent) {
			if (_touchEventId != cast(e, TouchEvent).touchPointID)
				return;
		}
		_touchEventId = -1;
		_down = false;
		resetVirtualTouchDisplay();
	}

	/**
	 * 重新计算虚拟按键的位置
	 */
	private function resetVirtualTouchDisplay():Void {
		if (!_down) {
			_orignPos.x = 0;
			_orignPos.y = 0;
			_touchPos.x = 0;
			_touchPos.y = 0;
			if (virtualTouchBGDisplay != null) {
				virtualTouchBGDisplay.x = 0;
				virtualTouchBGDisplay.y = 0;
			}
			if (virtualTouchDisplay != null) {
				virtualTouchDisplay.x = 0;
				virtualTouchDisplay.y = 0;
			}
			if (onVirtualUpdate != null)
				onVirtualUpdate(null);
			return;
		}
		// 当虚拟机超出点击有效范围后，需要重新计算原点
		var len = Point.distance(_touchPos, _orignPos);
		var radian = hx.geom.Point.radianByFloat(_orignPos.x, _orignPos.y, _touchPos.x, _touchPos.y);
		if (len > virtualTouchRadius && !fixedOrignPoint) {
			// 弧度
			var len2 = len - virtualTouchRadius;
			_orignPos.x += Math.cos(radian) * len2;
			_orignPos.y += Math.sin(radian) * len2;
			var len3 = Point.distance(_orignPos, _mathPos);
			if (len3 > virtualTouchOrginMaxRadius) {
				var radian2 = hx.geom.Point.radianByFloat(_orignPos.x, _orignPos.y, _mathPos.x, _mathPos.y);
				var len4 = len3 - virtualTouchOrginMaxRadius;
				_orignPos.x += Math.cos(radian2) * len4;
				_orignPos.y += Math.sin(radian2) * len4;
			}
		}
		// 需要重新计算
		len = Point.distance(_touchPos, _orignPos);
		if (len > virtualTouchRadius) {
			var radian = hx.geom.Point.radianByFloat(_orignPos.x, _orignPos.y, _touchPos.x, _touchPos.y);
			var len2 = len - virtualTouchRadius;
			_touchPos.x -= Math.cos(radian) * len2;
			_touchPos.y -= Math.sin(radian) * len2;
		}
		// 虚拟键渲染
		if (virtualTouchBGDisplay != null) {
			virtualTouchBGDisplay.x = _orignPos.x;
			virtualTouchBGDisplay.y = _orignPos.y;
		}
		if (virtualTouchDisplay != null) {
			virtualTouchDisplay.x = _touchPos.x;
			virtualTouchDisplay.y = _touchPos.y;
		}
		if (onVirtualUpdate != null) {
			onVirtualUpdate(radian);
		}
	}
}
