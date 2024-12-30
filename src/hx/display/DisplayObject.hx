package hx.display;

import hx.layout.LayoutData;
import hx.layout.ILayout;
import hx.gemo.ColorTransform;
import hx.gemo.Matrix;
import hx.gemo.Rectangle;
import hx.events.Event;

using hx.utils.MathUtils;

/**
 * 唯一统一的渲染对象
 */
@:keep
class DisplayObject extends EventDispatcher {
	@:noCompletion private var __scaleX:Float = 1;
	@:noCompletion private var __scaleY:Float = 1;
	@:noCompletion private var __rotation:Float = 0;
	@:noCompletion private var __rotationCosine:Float;
	@:noCompletion private var __rotationSine:Float;
	@:noCompletion private var __alpha:Float = 1;
	@:noCompletion private var __stage:Stage;
	@:noCompletion private var __parent:DisplayObjectContainer;
	@:noCompletion private var __visible:Bool = true;
	@:noCompletion private var __worldAlpha:Float = 1;
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
	@:noCompletion private var __colorTransform:ColorTransform;
	@:noCompletion private var __blendMode:BlendMode = NORMAL;
	@:noCompletion private var __colorTransformDirty = false;
	@:noCompletion private var __uvsDirty = false;
	@:noCompletion private var __layoutData:LayoutData;
	@:noCompletion private var __name:String;
	@:noCompletion private var __makRect:Rectangle;

	/**
	 * 遮罩居中
	 */
	public var makeRect(get, set):Rectangle;

	private function set_makeRect(value:Rectangle):Rectangle {
		__makRect = value;
		return value;
	}

	private function get_makeRect():Rectangle {
		return __makRect;
	}

	/**
	 * 原点偏移X，单位为像素
	 */
	public var originX(get, set):Float;

	private function set_originX(value:Float):Float {
		__originWorldX = value;
		this.setTransformDirty();
		return value;
	}

	private function get_originX():Float {
		return __originWorldX;
	}

	/**
	 * 原点偏移Y，单位为像素
	 */
	public var originY(get, set):Float;

	private function set_originY(value:Float):Float {
		__originWorldY = value;
		this.setTransformDirty();
		return value;
	}

	private function get_originY():Float {
		return __originWorldY;
	}

	/**
	 * 显示对象名称，可通过`getChildByName`方法获取
	 */
	public var name(get, set):String;

	private function get_name():String {
		return __name;
	}

	private function set_name(value:String):String {
		__name = value;
		return value;
	}

	/**
	 * 布局数据
	 */
	public var layoutData(get, set):LayoutData;

	private function set_layoutData(value:LayoutData):LayoutData {
		__layoutData = value;
		return value;
	}

	private function get_layoutData():LayoutData {
		return __layoutData;
	}

	/**
	 * 混合模式决定了对象如何与下面的对象混合。
	 */
	public var blendMode(get, set):BlendMode;

	private function get_blendMode():BlendMode {
		return __blendMode;
	}

	private function set_blendMode(value:BlendMode):BlendMode {
		__blendMode = value;
		this.setDirty();
		return value;
	}

	public var colorTransform(get, set):ColorTransform;

	private function get_colorTransform():ColorTransform {
		return __colorTransform != null ? __colorTransform.clone() : null;
	}

	private function set_colorTransform(value:ColorTransform):ColorTransform {
		if (__colorTransform == null) {
			__colorTransform = new ColorTransform();
		}
		__colorTransform.setTo(value);
		__colorTransformDirty = true;
		return value;
	}

	/**
	 * 获得矩阵
	 */
	public var transform(get, set):Matrix;

	private function get_transform():Matrix {
		return this.__transform;
	}

	private function set_transform(value:Matrix):Matrix {
		__setTransform(value.a, value.b, value.c, value.d, value.tx, value.ty);
		return value;
	}

	@:noCompletion private function __setTransform(a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float):Void {
		var transform = this.__transform;
		if (transform.a == a && transform.b == b && transform.c == c && transform.d == d && transform.tx == tx && transform.ty == ty) {
			return;
		}

		var scaleX = 0.0;
		var scaleY = 0.0;

		if (b == 0) {
			scaleX = a;
		} else {
			scaleX = Math.sqrt(a * a + b * b);
		}

		if (c == 0) {
			scaleY = d;
		} else {
			scaleY = Math.sqrt(c * c + d * d);
		}

		this.__scaleX = scaleX;
		this.__scaleY = scaleY;

		var rotation = (180 / Math.PI) * Math.atan2(d, c) - 90;

		if (rotation != this.__rotation) {
			this.__rotation = rotation;
			var radians = rotation * (Math.PI / 180);
			this.__rotationSine = Math.sin(radians);
			this.__rotationCosine = Math.cos(radians);
		}

		transform.a = a;
		transform.b = b;
		transform.c = c;
		transform.d = d;
		transform.tx = tx;
		transform.ty = ty;

		this.setTransformDirty();
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
			this.__worldTransform.concat(__transform);
			this.__worldTransform.translate(this.__originWorldX, this.__originWorldY);
			this.__worldTransform.concat(parent.__worldTransform);
		}
		// this.__transformDirty = false;
	}

	/**
	 * 宽度
	 */
	public var width(get, set):Float;

	private function get_width():Float {
		if (__width != null) {
			return __width;
		}
		return getBounds().width;
	}

	private function set_width(value:Float):Float {
		this.__width = value;
		var bounds = __getRect();
		this.scaleX = value / bounds.width;
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
		return getBounds().height;
	}

	private function set_height(value:Float):Float {
		this.__height = value;
		var bounds = __getRect();
		this.scaleY = value / bounds.height;
		setTransformDirty();
		return value;
	}

	/**
	 * 重置尺寸
	 * @param width 
	 * @param height 
	 */
	public function resize(?width:Null<Float>, ?height:Null<Float>):Void {
		this.__width = width;
		this.__height = height;
		setTransformDirty();
	}

	/**
	 * 获得边界
	 * @return Rectangle
	 */
	public function getBounds(parent:Matrix = null):Rectangle {
		if (parent != null) {
			var t = __transform.clone();
			t.concat(parent);
			return __getLocalBounds(__getRect(), t);
		} else {
			return __getLocalBounds(__getRect());
		}
	}

	private function __getRect():Rectangle {
		return __rect;
	}

	/**
	 * 获取显示对象的边界
	 * @return Rectangle
	 */
	private function __getLocalBounds(rect:Rectangle, parent:Matrix = null):Rectangle {
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
		__transform.tx = value;
		setTransformDirty();
		return value;
	}

	private function get_x():Float {
		return __transform.tx;
	}

	/**
	 * 呈现在屏幕上的y坐标，该引擎的坐标系是左上角为原点，x轴向右为正，y轴向下为正
	 */
	public var y(get, set):Float;

	private function set_y(value:Float):Float {
		__transform.ty = value;
		setTransformDirty();
		return value;
	}

	private function get_y():Float {
		return __transform.ty;
	}

	/**
	 * 显示对象的x比例渲染缩放，默认为1
	 */
	public var scaleX(get, set):Float;

	private function set_scaleX(value:Float):Float {
		if (value != __scaleX) {
			__scaleX = value;
			if (__transform.b == 0) {
				if (value != __transform.a)
					setTransformDirty();
				__transform.a = value;
			} else {
				var a = __rotationCosine * value;
				var b = __rotationSine * value;
				if (__transform.a != a || __transform.b != b) {
					setTransformDirty();
				}
				__transform.a = a;
				__transform.b = b;
			}
		}
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
		if (value != __scaleY) {
			__scaleY = value;
			if (__transform.c == 0) {
				if (value != __transform.d)
					setTransformDirty();
				__transform.d = value;
			} else {
				var c = -__rotationSine * value;
				var d = __rotationCosine * value;
				if (__transform.d != d || __transform.c != c) {
					setTransformDirty();
				}
				__transform.c = c;
				__transform.d = d;
			}
		}
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
		if (value != __rotation) {
			__rotation = value;
			var radians = __rotation * (Math.PI / 180);
			__rotationSine = Math.sin(radians);
			__rotationCosine = Math.cos(radians);
			__transform.a = __rotationCosine * __scaleX;
			__transform.b = __rotationSine * __scaleX;
			__transform.c = -__rotationSine * __scaleY;
			__transform.d = __rotationCosine * __scaleY;
			setTransformDirty();
		}
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
		__colorTransformDirty = true;
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
		__rotation = 0;
		__rotationSine = 0;
		__rotationCosine = 1;
		__scaleX = 1;
		__scaleY = 1;
		// __colorTransform = new ColorTransform();
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
		if (!mouseEnabled || !this.visible) {
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

	/**
	 * 销毁所有有关显示对象的资源引用
	 */
	public function dispose():Void {}
}
