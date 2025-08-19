package hx.display;

import hx.geom.PerspectiveProjection;
import hx.geom.Vector3D;
import hx.geom.TransformMatrix3D;
import hx.geom.Matrix3D;
import hx.geom.Point;
import hx.core.Hxmaker;
import hx.layout.LayoutData;
import hx.layout.ILayout;
import hx.geom.ColorTransform;
import hx.geom.Matrix;
import hx.geom.Rectangle;
import hx.events.Event;

using hx.utils.MathUtils;

/**
 * 唯一统一的渲染对象
 */
@:keep
@:access(hx.geom.Matrix)
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
	@:noCompletion private var __transformMatrix3D:TransformMatrix3D;
	// @:noCompletion private var __worldTransformMatrix3D:Matrix3D;
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
	@:noCompletion private var __maskRect:Rectangle;
	@:noCompletion private var __background:DisplayObject;
	@:noCompletion private var __shader:Shader;

	/**
	 * 着色器设置
	 * - OpenFL目标：使用的着色器是GraphicsShader，请依赖GraphicsShader来实现自定义的Shader。
	 */
	public var shader(get, set):Shader;

	private function get_shader():Shader {
		return __shader;
	}

	private function set_shader(value:Shader):Shader {
		if (__shader != value) {
			__shader = value;
			this.setDirty();
		}
		return value;
	}

	/**
	 * 背景显示对象
	 */
	public var background(get, set):DisplayObject;

	private function set_background(value:DisplayObject):DisplayObject {
		__background = value;
		if (value != null) {
			value.setTransformDirty();
			value.setDirty();
		}
		return value;
	}

	private function get_background():DisplayObject {
		return __background;
	}

	/**
	 * 遮罩居中
	 */
	public var maskRect(get, set):Rectangle;

	private function set_maskRect(value:Rectangle):Rectangle {
		__maskRect = value;
		return value;
	}

	private function get_maskRect():Rectangle {
		return __maskRect;
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
		if (value == null) {
			this.__colorTransform = null;
			__colorTransformDirty = true;
			return value;
		}
		if (__colorTransform == null) {
			__colorTransform = new ColorTransform();
		}
		__colorTransform.setTo(value);
		__colorTransformDirty = true;
		return value;
	}

	/**
	 * 设置3D矩阵
	 */
	public var matrix3D(get, set):hx.geom.Matrix3D;

	private function set_matrix3D(value:hx.geom.Matrix3D):hx.geom.Matrix3D {
		this.__transformMatrix3D.transform3D = value;
		return value;
	}

	private function get_matrix3D():hx.geom.Matrix3D {
		return this.__transformMatrix3D.transform3D;
	}

	public var center3DVector(get, set):Vector3D;

	private function set_center3DVector(value:Vector3D):Vector3D {
		this.__transformMatrix3D.center3DVector = value;
		return value;
	}

	private function get_center3DVector():Vector3D {
		return this.__transformMatrix3D.center3DVector;
	}

	// public var projection(get, set):PerspectiveProjection;
	// private function set_projection(value:PerspectiveProjection):PerspectiveProjection {
	// 	this.__transformMatrix3D.projection = value;
	// 	return value;
	// }
	// private function get_projection():PerspectiveProjection {
	// 	return this.__transformMatrix3D.projection;
	// }
	public var projectionMatrix3D(get, set):Matrix3D;

	private function set_projectionMatrix3D(value:Matrix3D):Matrix3D {
		this.__transformMatrix3D.projectionMatrix3D = value;
		return value;
	}

	private function get_projectionMatrix3D():Matrix3D {
		return this.__transformMatrix3D.projectionMatrix3D;
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
			this.__worldTransform.translate(this.__originWorldX, this.__originWorldY);
			this.__worldTransform.concat(__transform);
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
			return __width * this.scaleX;
		}
		return __getBounds().width;
	}

	private function set_width(value:Float):Float {
		this.__width = value;
		var bounds = __getRect();
		if (bounds.width == 0)
			this.scaleX = 1;
		else
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
			return __height * this.scaleY;
		}
		return __getBounds().height;
	}

	private function set_height(value:Float):Float {
		this.__height = value;
		var bounds = __getRect();
		if (bounds.height == 0)
			this.scaleY = 1;
		else
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
	public function getBounds(targetCoordinateSpace:DisplayObject = null):Rectangle {
		if (this.__transformDirty && stage != null)
			stage.__updateTransform(null);
		var matrix = new Matrix();
		if (targetCoordinateSpace != null && targetCoordinateSpace != this) {
			matrix.copyFrom(this.__worldTransform);
			var targetMatrix = targetCoordinateSpace.__worldTransform.clone();
			targetMatrix.invert();
			matrix.concat(targetMatrix);
		}

		var bounds = __getRect();
		var rect = new Rectangle();
		bounds.transform(rect, matrix);
		return rect;
	}

	private function __getRect():Rectangle {
		return __rect;
	}

	private function __getBounds(parent:Matrix = null):Rectangle {
		if (parent != null) {
			var t = __transform.clone();
			t.concat(parent);
			return __getLocalBounds(__getRect(), t);
		} else {
			return __getLocalBounds(__getRect());
		}
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
		// __worldTransformMatrix3D = new Matrix3D();
		__rect = new Rectangle();
		__transformMatrix3D = new TransformMatrix3D();
		this.onBuildUI();
		this.onInit();
	}

	private function onBuildUI():Void {}

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
		if (this.hasEventListener(Event.ADDED_TO_STAGE))
			this.dispatchEvent(new Event(Event.ADDED_TO_STAGE));
	}

	private function __onRemoveFromStage():Void {
		if (this.hasEventListener(Event.REMOVED_FROM_STAGE))
			this.dispatchEvent(new Event(Event.REMOVED_FROM_STAGE));
		this.onRemoveToStage();
		this.__stage = null;
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
		if (maskRect != null) {
			// 必须命中在maskRect之内的区域
			var rect = this.__getWorldLocalBounds(maskRect);
			if (!rect.containsPoint(x, y)) {
				return false;
			}
		}
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
		if (maskRect != null) {
			// 必须命中在maskRect之内的区域
			var rect = this.__getWorldLocalBounds(maskRect);
			if (!rect.containsPoint(x, y)) {
				return false;
			}
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

	/**
	 * 获得顶部渲染层
	 */
	public var topView(get, never):Stage;

	private function get_topView():Stage {
		return Hxmaker.topView;
	}

	/**
	 * 本地坐标转换为世界坐标
	 * @param point 
	 * @return Point
	 */
	public function localToGlobal(point:Point):Point {
		if (this.__transformDirty && stage != null)
			stage.__updateTransform(null);
		var p = point.clone();
		p.x = __worldTransform.__transformX(p.x, p.y);
		p.y = __worldTransform.__transformY(p.x, p.y);
		return p;
	}

	/**
	 * 世界坐标转换为本地坐标
	 * @param point 
	 * @return Point
	 */
	public function globalToLocal(point:Point):Point {
		if (this.__transformDirty && stage != null)
			stage.__updateTransform(null);
		var p = point.clone();
		p.x = __worldTransform.__transformInverseX(p.x, p.y);
		p.y = __worldTransform.__transformInverseY(p.x, p.y);
		return p;
	}

	/**
	 * 获得相对当前对象的触摸坐标X
	 */
	public var touchX(get, never):Float;

	private function get_touchX():Float {
		if (this.__transformDirty)
			stage.__updateTransform(null);
		return this.__worldTransform.__transformInverseX(Hxmaker.engine.touchX, Hxmaker.engine.touchY);
	}

	/**
	 * 获得相对当前对象的触摸坐标Y
	 */
	public var touchY(get, never):Float;

	private function get_touchY():Float {
		if (this.__transformDirty)
			stage.__updateTransform(null);
		return this.__worldTransform.__transformInverseY(Hxmaker.engine.touchX, Hxmaker.engine.touchY);
	}

	override function dispatchEvent(event:Event) {
		if (event.target == null) {
			event.target = this;
		}
		super.dispatchEvent(event);
		if (event.bubbling) {
			if (this.parent != null) {
				this.parent.dispatchEvent(event);
			}
		}
	}

	/**
	 * 删除自已
	 */
	public function remove():Void {
		if (this.parent != null)
			this.parent.removeChild(this);
	}
}
