package hx.displays;

import hx.gemo.Rectangle;
import hx.providers.IRootDataProvider;

/**
 * 使用位图进行渲染的图像
 */
@:keep
class Image extends DisplayObject implements IDataProider<BitmapData> implements IRootDataProvider<Dynamic> {
	@:noCompletion private var __bitmapData:BitmapData;
	@:noCompletion private var __smoothing:Bool = true;
	@:noCompletion private var __graphic:Graphic;
	@:noCompletion private var __scale9Grid:Rectangle;
	@:noCompletion private var __scale9GridDirty:Bool = false;

	public var root(get, set):Dynamic;

	@:noCompletion private function get_root():Dynamic {
		return __root;
	}

	@:noCompletion private function set_root(value:Dynamic):Dynamic {
		this.__root = value;
		return __root;
	}

	/**
	 * 九宫格缩放矩形，会根据矩形的left/right/top/bottom的值来裁剪位图，并拉伸填充。
	 */
	public var scale9Grid(get, set):Rectangle;

	private function get_scale9Grid():Rectangle {
		return __scale9Grid;
	}

	/**
	 * 获得九宫格图已渲染的图形
	 * @return Graphic
	 */
	private function getScale9GridGraphic():Graphic {
		if (__scale9Grid != null) {
			if (__graphic == null) {
				__graphic = new Graphic();
			}
			if (__scale9GridDirty) {
				__scale9GridDirty = false;
				__graphic.clear();
				// __graphic.drawTriangles();
				__graphic.beginBitmapData(this.data);
				__graphic.drawRect(__scale9Grid.x, __scale9Grid.y, __scale9Grid.width, __scale9Grid.height);
			}
		}
		return __graphic;
	}

	private function set_scale9Grid(value:Rectangle):Rectangle {
		__scale9Grid = value;
		this.setDirty();
		this.__scale9GridDirty = true;
		return __scale9Grid;
	}

	/**
	 * 设置、获取位图数据
	 */
	public var data(get, set):BitmapData;

	private function set_data(value:BitmapData):BitmapData {
		__bitmapData = value;
		return value;
	}

	private function get_data():BitmapData {
		return __bitmapData;
	}

	/**
	 * 平滑处理，默认为`false`
	 */
	public var smoothing(get, set):Bool;

	private function set_smoothing(value:Bool):Bool {
		__smoothing = value;
		return value;
	}

	private function get_smoothing():Bool {
		return __smoothing;
	}

	/**
	 * 构造一个位图对象
	 * @param data 
	 */
	public function new(?data:BitmapData) {
		super();
		if (data != null) {
			this.data = data;
		}
	}

	override function __getRect():Rectangle {
		if (data != null) {
			if (data.frameRect != null) {
				__rect.x = data.frameRect.x;
				__rect.y = data.frameRect.y;
				__rect.width = data.frameRect.width;
				__rect.height = data.frameRect.height;
			} else if (data.rect != null) {
				__rect.width = data.rect.width;
				__rect.height = data.rect.height;
			} else {
				__rect.width = data.data.getWidth();
				__rect.height = data.data.getHeight();
			}
		}
		return super.__getRect();
	}
}
