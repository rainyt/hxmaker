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
				// __graphic.transform = this.transform;
				__graphic.x = this.x;
				__graphic.y = this.y;
				__graphic.rotation = this.rotation;
				__graphic.__updateTransform(this.parent);
				__graphic.beginBitmapData(this.data);
				var rect = __scale9Grid;
				trace(rect.left, rect.right, rect.width);

				var rightWidth = (this.data.data.getWidth() - rect.x - rect.width);
				var leftWidth = rect.x;
				var topHeight = rect.y;
				var bottomHeight = (this.data.data.getHeight() - rect.y - rect.height);
				// 左上
				/**
					* 
					* [
						0,
						0,
						leftWidth / rect.width,
						0,
						0,
						topHeight / rect.height,
						leftWidth / rect.width,
						topHeight / rect.height
					]
				 */
				var textureWidth = this.data.data.getWidth();
				var textureHeight = this.data.data.getHeight();
				__graphic.drawRectUVs(0, 0, leftWidth, topHeight, maskUVs(0, 0, leftWidth, topHeight, textureWidth, textureHeight));
				// 右上
				__graphic.drawRectUVs(this.width - rightWidth, 0, rightWidth, topHeight,
					maskUVs(rect.right, 0, rightWidth, topHeight, textureWidth, textureHeight));
				// 左下
				__graphic.drawRectUVs(0, this.height - bottomHeight, leftWidth, bottomHeight,
					maskUVs(0, rect.bottom, rightWidth, topHeight, textureWidth, textureHeight));
				// 右下
				__graphic.drawRectUVs(this.width - rightWidth, this.height - bottomHeight, rightWidth, bottomHeight,
					maskUVs(rect.right, rect.bottom, rightWidth, topHeight, textureWidth, textureHeight));
				// 中间
				__graphic.drawRectUVs(rect.left, rect.top, this.width - rightWidth - rect.left, this.height - bottomHeight - rect.top,
					maskUVs(rect.x, rect.y, rect.width, rect.height, textureWidth, textureHeight));
				// 左边中间
				__graphic.drawRectUVs(0, topHeight, leftWidth, this.height - bottomHeight - topHeight,
					maskUVs(0, rect.y, leftWidth, rect.height, textureWidth, textureHeight));
				// 右边中间
				__graphic.drawRectUVs(this.width - rightWidth, topHeight, rightWidth, this.height - bottomHeight - topHeight,
					maskUVs(rect.right, rect.y, rightWidth, rect.height, textureWidth, textureHeight));
				// 上面中间
				__graphic.drawRectUVs(leftWidth, 0, width - leftWidth - rightWidth, topHeight,
					maskUVs(rect.x, 0, rect.width, topHeight, textureWidth, textureHeight));
				// 下面中间
				__graphic.drawRectUVs(leftWidth, height - bottomHeight, width - leftWidth - rightWidth, bottomHeight,
					maskUVs(rect.x, rect.bottom, rect.width, bottomHeight, textureWidth, textureHeight));
			}
		}
		return __graphic;
	}

	private function maskUVs(x:Float, y:Float, w:Float, h:Float, textureWidth:Float, textureHeight:Float):Array<Float> {
		return [
			x / textureWidth,
			y / textureHeight,
			(x + w) / textureWidth,
			y / textureHeight,
			x / textureWidth,
			(y + h) / textureHeight,
			(x + w) / textureWidth,
			(y + h) / textureHeight
		];
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

	override function setTransformDirty(value:Bool = true) {
		super.setTransformDirty(value);
		__scale9GridDirty = true;
	}
}
