package hx.displays;

import hx.gemo.Matrix;
import hx.gemo.Rectangle;
import hx.events.Event;

using hx.utils.MathUtils;

/**
 * 唯一统一的渲染对象
 */
@:keep
class DisplayObject extends EventDispatcher {
	@:noCompletion private var __x:Float = 0;
	@:noCompletion private var __y:Float = 0;
	@:noCompletion private var __scaleX:Float = 1;
	@:noCompletion private var __scaleY:Float = 1;
	@:noCompletion private var __rotation:Float = 0;
	@:noCompletion private var __alpha:Float = 1;
	@:noCompletion private var __stage:Stage;
	@:noCompletion private var __parent:DisplayObjectContainer;
	@:noCompletion private var __visible:Bool = true;
	// @:noCompletion private var __worldX:Float = 0;
	// @:noCompletion private var __worldY:Float = 0;
	@:noCompletion private var __worldAlpha:Float = 1;
	// @:noCompletion private var __worldRotation:Float = 0;
	// @:noCompletion private var __worldScaleX:Float = 1;
	// @:noCompletion private var __worldScaleY:Float = 1;
	@:noCompletion private var __root:Dynamic;
	@:noCompletion private var __dirty:Bool = true;
	@:noCompletion private var __transformDirty:Bool = true;
	@:noCompletion private var __width:Null<Float> = null;
	@:noCompletion private var __height:Null<Float> = null;
	@:noCompletion private var __transform:Matrix;
	@:noCompletion private var __worldTransform:Matrix;
	@:noCompletion private var __rect:Rectangle;
	@:noCompletion private var __stageInit:Bool = false;
	@:noCompletion private var __mouseEnabled:Bool = true;
	@:noCompletion private var __originWorldX = 0.;
	@:noCompletion private var __originWorldY = 0.;

	/**
	 * 获得矩阵
	 */
	public var transform(get, set):Matrix;

	private function get_transform():Matrix {
		if (__transformDirty) {
			__updateTransform(null);
		}
		return this.__transform;
	}

	private function set_transform(value:Matrix):Matrix {
		__transform = value;
		return value;
	}

	/**
	 * 当前显示对象是否允许被触摸
	 */
	public var mouseEnabled(get, set):Bool;

	private function set_mouseEnabled(value:Bool):Bool {
		__mouseEnabled = value;
		return value;
	}

	private function get_mouseEnabled():Bool {
		return __mouseEnabled;
	}

	/**
	 * 更新tranform
	 * @param parent 如果提供了parent，则会根据parent更新worldTransform
	 */
	private function __updateTransform(parent:DisplayObject):Void {
		if (parent != null) {
			this.__worldAlpha = parent.__worldAlpha * this.__alpha;
			// 世界矩阵
			this.__worldTransform.identity();
			this.__worldTransform.scale(this.__scaleX, this.__scaleY);
			this.__worldTransform.rotate(this.__rotation.rotationToRadian());
			this.__worldTransform.translate(this.__x, this.__y);
			this.__worldTransform.translate(this.__originWorldX, this.__originWorldY);
			this.__worldTransform.concat(parent.__worldTransform);
		}
		// 自身矩阵
		this.__transform.identity();
		this.__transform.scale(this.__scaleX, this.__scaleY);
		this.__transform.rotate(this.__rotation.rotationToRadian());
		this.__transform.translate(this.__x, this.__y);
		this.__transformDirty = false;
	}

	/**
	 * 宽度
	 */
	public var width(get, set):Float;

	private function get_width():Float {
		if (__width != null) {
			return __width;
		}
		return __getLocalBounds(__getRect()).width;
	}

	private function set_width(value:Float):Float {
		this.__width = value;
		setTransformDirty();
		return value;
	}

	/**
	 * 高度
	 */
	public var height(get, set):Float;

	private function get_height():Float {
		if (__height != null) {
			return __height;
		}
		return __getLocalBounds(__getRect()).height;
	}

	/**
	 * 获得边界
	 * @return Rectangle
	 */
	public function getBounds(parent:Matrix = null):Rectangle {
		if (parent != null) {
			var t = parent.clone();
			t.concat(__transform);
			return __getLocalBounds(__getRect(), t);
		} else {
			return __getLocalBounds(__getRect());
		}
	}

	private function set_height(value:Float):Float {
		this.__height = value;
		setTransformDirty();
		return value;
	}

	@:noCompletion private function __getRect():Rectangle {
		return __rect;
	}

	/**
	 * 获取显示对象的边界
	 * @return Rectangle
	 */
	private function __getLocalBounds(rect:Rectangle, parent:Matrix = null):Rectangle {
		// 如果存在变换矩阵，则使用变换矩阵计算边界
		if (__transformDirty) {
			__updateTransform(null);
		}
		var ret = new Rectangle();
		if (parent != null) {
			rect.transform(ret, parent);
		} else {
			rect.transform(ret, __transform);
		}
		return ret;
	}

	/**
	 * 获得显示对象的世界边界
	 * @param rect 
	 * @return Rectangle
	 */
	private function __getWorldLocalBounds(rect:Rectangle):Rectangle {
		// 如果存在变换矩阵，则使用变换矩阵计算边界
		var ret = new Rectangle();
		rect.transform(ret, __worldTransform);
		return ret;
	}

	/**
	 * 设置显示对象是否可见，当不可见时，不会参与渲染，也不会参与交互
	 */
	public var visible(get, set):Bool;

	public function set_visible(value:Bool):Bool {
		this.setDirty();
		return __visible = value;
	}

	public function get_visible():Bool {
		return __visible;
	}

	/**
	 * 呈现在屏幕上的x坐标，该引擎的坐标系是左上角为原点，x轴向右为正，y轴向下为正
	 */
	public var x(get, set):Float;

	private function set_x(value:Float):Float {
		__x = value;
		setTransformDirty();
		return value;
	}

	private function get_x():Float {
		return __x;
	}

	/**
	 * 呈现在屏幕上的y坐标，该引擎的坐标系是左上角为原点，x轴向右为正，y轴向下为正
	 */
	public var y(get, set):Float;

	private function set_y(value:Float):Float {
		__y = value;
		setTransformDirty();
		return value;
	}

	private function get_y():Float {
		return __y;
	}

	/**
	 * 显示对象的x比例渲染缩放，默认为1
	 */
	public var scaleX(get, set):Float;

	private function set_scaleX(value:Float):Float {
		__scaleX = value;
		setTransformDirty();
		return value;
	}

	private function get_scaleX():Float {
		return __scaleX;
	}

	/**
	 * 显示对象的y比例渲染缩放，默认为1
	 */
	public var scaleY(get, set):Float;

	private function set_scaleY(value:Float):Float {
		__scaleY = value;
		setTransformDirty();
		return value;
	}

	private function get_scaleY():Float {
		return __scaleY;
	}

	/**
	 * 设置显示对象的旋转角度，默认为0
	 */
	public var rotation(get, set):Float;

	private function set_rotation(value:Float):Float {
		__rotation = value;
		setTransformDirty();
		return value;
	}

	private function get_rotation():Float {
		return __rotation;
	}

	/**
	 * 设置显示对象的透明度，默认为1
	 */
	public var alpha(get, set):Float;

	private function set_alpha(value:Float):Float {
		__alpha = value;
		this.setDirty();
		return value;
	}

	private function get_alpha():Float {
		return __alpha;
	}

	/**
	 * 获得当前对象的舞台对象
	 */
	public var stage(get, null):Stage;

	private function get_stage():Stage {
		return __stage;
	}

	/**
	 * 获得当前对象的父节点对象
	 */
	public var parent(get, null):DisplayObjectContainer;

	private function get_parent():DisplayObjectContainer {
		return __parent;
	}

	/**
	 * 构造一个显示对象
	 */
	public function new() {
		__transform = new Matrix();
		__worldTransform = new Matrix();
		__rect = new Rectangle();
		this.onInit();
	}

	/**
	 * 当对象被创建时调用，一般用于初始化对象
	 */
	public function onInit():Void {}

	private function __onAddToStage(stage:Stage):Void {
		this.__stage = stage;
		if (!__stageInit) {
			__stageInit = true;
			this.onStageInit();
		}
		this.onAddToStage();
	}

	/**
	 * 从舞台初始化时触发，该函数每个周期只会触发一次
	 */
	public function onStageInit():Void {}

	/**
	 * 当对象被添加到舞台时调用，一般用于添加事件监听
	 */
	public function onAddToStage():Void {}

	/**
	 * 当对象从舞台中移除时调用，一般用于移除事件监听
	 */
	public function onRemoveToStage():Void {}

	/**
	 * 是否启用帧事件更新
	 */
	public var updateEnabled:Bool = false;

	/**
	 * 每帧调用，一般用于更新对象状态，启动它需要设置`updateEnable`为`true`。请注意，如果显示对象不存在`stage`时，则不会调用。
	 * @param dt 
	 */
	public function onUpdate(dt:Float):Void {
		if (hasEventListener(Event.UPDATE)) {
			dispatchEvent(new Event(Event.UPDATE));
		}
	}

	/**
	 * 标记为脏，需要刷新渲染
	 */
	public function invalidate():Void {
		this.setTransformDirty();
	}

	/**
	 * 设置为脏
	 * @param value 
	 */
	private function setDirty(value:Bool = true):Void {
		this.__dirty = value;
		if (value && stage != null && stage != this) {
			this.stage.setDirty();
		}
	}

	/**
	 * 设置转换为脏
	 * @param value 
	 */
	private function setTransformDirty(value:Bool = true):Void {
		this.__transformDirty = value;
		this.setDirty();
	}

	/**
	 * 通关世界坐标测试是否碰撞
	 * @param x 
	 * @param y 
	 * @return Bool
	 */
	public function hitTestWorldPoint(x:Float, y:Float):Bool {
		var rect = this.__getWorldLocalBounds(__getRect());
		if (rect.containsPoint(x, y)) {
			return true;
		}
		return false;
	}

	/**
	 * 点击测试
	 * @param x 
	 * @param y 
	 * @param stacks 
	 * @return DisplayObject
	 */
	private function __hitTest(x:Float, y:Float, stacks:Array<DisplayObject>):Bool {
		if (!mouseEnabled) {
			return false;
		}
		if (hitTestWorldPoint(x, y)) {
			stacks.push(this);
			return true;
		}
		return false;
	}

	public function toString():String {
		return "[object " + getType() + "]";
	}

	public function getType():String {
		return Type.getClassName(Type.getClass(this));
	}
}
