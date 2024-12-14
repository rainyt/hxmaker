package hx.displays;

/**
 * 唯一统一的渲染对象
 */
@:keep
class DisplayObject {
	@:noCompletion private var __x:Float = 0;
	@:noCompletion private var __y:Float = 0;
	@:noCompletion private var __scaleX:Float = 1;
	@:noCompletion private var __scaleY:Float = 1;
	@:noCompletion private var __rotation:Float = 0;
	@:noCompletion private var __alpha:Float = 1;
	@:noCompletion private var __stage:Stage;
	@:noCompletion private var __parent:DisplayObject;

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
	public var parent(get, null):DisplayObject;

	private function get_parent():DisplayObject {
		return __parent;
	}

	/**
	 * 构造一个显示对象
	 */
	public function new() {
		this.onInit();
	}

	/**
	 * 当对象被创建时调用，一般用于初始化对象
	 */
	public function onInit():Void {}

	/**
	 * 当对象被添加到舞台时调用，一般用于添加事件监听
	 */
	public function onAddToStage():Void {}

	/**
	 * 当对象从舞台中移除时调用，一般用于移除事件监听
	 */
	public function onRemoveToStage():Void {}
}
