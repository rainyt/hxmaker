package hx.display;

import hx.gemo.Rectangle;
import hx.gemo.ColorTransform;
import hx.utils.ColorUtils;
import hx.providers.IRootDataProvider;

/**
 * 矩形渲染显示对象
 */
class Quad extends Graphics implements IDataProider<UInt> implements IRootDataProvider<Dynamic> {
	public var root(get, set):Dynamic;

	@:noCompletion private function get_root():Dynamic {
		return __root;
	}

	@:noCompletion private function set_root(value:Dynamic):Dynamic {
		this.__root = value;
		return __root;
	}

	/**
	 * 设置颜色值
	 */
	public var data(get, set):UInt;

	private var _data:UInt;

	public function get_data():UInt {
		return _data;
	}

	public function set_data(value:UInt):UInt {
		_data = value;
		__quadDirty = true;
		return value;
	}

	/**
	 * 构造一个色块渲染对象
	 * @param width 宽度
	 * @param height 高度
	 * @param color 颜色
	 */
	public function new(width:Float = 0, height:Float = 0, color:UInt = 0x0) {
		super();
		this.width = width;
		this.height = height;
		this.data = color;
		__quadDirty = true;
	}

	private var __quadDirty:Bool = false;

	override function set_width(value:Float):Float {
		this.__width = value;
		__quadDirty = true;
		setTransformDirty();
		return value;
	}

	override function set_height(value:Float):Float {
		this.__height = value;
		__quadDirty = true;
		setTransformDirty();
		return value;
	}

	override function __getRect():Rectangle {
		__updateQuad();
		return super.__getRect();
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
		__updateQuad();
	}

	private function __updateQuad() {
		if (__quadDirty) {
			this.clear();
			this.beginFill(this.data);
			var color = ColorUtils.toShaderColor(this.data);
			this.drawRect(0, 0, this.width, this.height, this.alpha, new ColorTransform(color.r, color.g, color.b, 1));
			__quadDirty = false;
		}
	}
}
