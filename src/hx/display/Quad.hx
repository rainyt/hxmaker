package hx.display;

import hx.gemo.ColorTransform;
import hx.utils.ColorUtils;
import hx.providers.IRootDataProvider;

/**
 * 矩形渲染显示对象
 */
class Quad extends Graphic implements IDataProider<UInt> implements IRootDataProvider<Dynamic> {
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
	public function new(width:Int = 0, height:Int = 0, color:UInt = 0x0) {
		super();
		this.width = width;
		this.height = height;
		this.data = color;
		__quadDirty = true;
	}

	private var __quadDirty:Bool = false;

	override function set_width(value:Float):Float {
		__quadDirty = true;
		return super.set_width(value);
	}

	override function set_height(value:Float):Float {
		__quadDirty = true;
		return super.set_height(value);
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
		if (__quadDirty) {
			this.clear();
			this.beginFill(this.data);
			var color = ColorUtils.toShaderColor(this.data);
			this.drawRect(0, 0, this.width, this.height, this.alpha, new ColorTransform(color.r, color.g, color.b, 1));
			__quadDirty = false;
		}
	}
}