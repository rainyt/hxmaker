package hx.displays;

import hx.gemo.Rectangle;
import hx.events.Event;

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
	@:noCompletion private var __worldX:Float = 0;
	@:noCompletion private var __worldY:Float = 0;
	@:noCompletion private var __worldAlpha:Float = 1;
	@:noCompletion private var __worldRotation:Float = 0;
	@:noCompletion private var __worldScaleX:Float = 1;
	@:noCompletion private var __worldScaleY:Float = 1;
	@:noCompletion private var __root:Dynamic;
	@:noCompletion private var __autoInit:Bool = false;

	/**
	 * 根渲染显示对象，不同的引擎中对应的显示对象
	 */
	public var root(get, set):Dynamic;

	private function set_root(value:Dynamic):Dynamic {
		this.__root = value;
		return value;
	}

	private function get_root():Dynamic {
		return this.__root;
	}

	/**
	 * 更新tranform
	 * @param parent 
	 */
	private function __tranform(parent:DisplayObject):Void {
		this.__worldX = parent.__worldX + this.__x;
		this.__worldY = parent.__worldY + this.__y;
		this.__worldAlpha = parent.__worldAlpha * this.__alpha;
		this.__worldRotation = parent.__worldRotation + this.__rotation;
		this.__worldScaleX = parent.__worldScaleX * this.__scaleX;
		this.__worldScaleY = parent.__worldScaleY * this.__scaleY;
	}

	/**
	 * 宽度
	 */
	public var width(get, set):Float;

	private function get_width():Float {
		return 0;
	}

	private function set_width(value:Float):Float {
		return value;
	}

	/**
	 * 高度
	 */
	public var height(get, set):Float;

	private function get_height():Float {
		return 0;
	}

	private function set_height(value:Float):Float {
		return value;
	}

	/**
	 * 获取显示对象的边界
	 * @return Rectangle
	 */
	private function __getBounds():Rectangle {
		return null;
	}

	/**
	 * 设置显示对象是否可见，当不可见时，不会参与渲染，也不会参与交互
	 */
	public var visible(get, set):Bool;

	public function set_visible(value:Bool):Bool {
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
		if (__autoInit)
			this.onInit();
	}

	/**
	 * 当对象被创建时调用，一般用于初始化对象
	 */
	public function onInit():Void {}

	private function __onAddToStage(stage:Stage):Void {
		this.__stage = stage;
		this.onAddToStage();
	}

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
}
