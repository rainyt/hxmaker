package hx.display;

import hx.gemo.Rectangle;
import hx.providers.IRootDataProvider;

/**
 * 图像是一个映射了纹理的四边形。
 * 首先，它提供了一个方便的构造函数，可以自动将图像的大小与显示的纹理同步。
 * 此外，它还增加了对`scale9Grid`网格的支持。这将图像分为九个区域，其角落将始终保持其原始大小。中心区域在两个方向上延伸以填充剩余空间；侧部区域将相应地在水平或垂直方向上拉伸。
 */
@:keep
class Image extends DisplayObject implements IDataProider<BitmapData> implements IRootDataProvider<Dynamic> {
	@:noCompletion private var __bitmapData:BitmapData;
	@:noCompletion private var __smoothing:Bool = true;
	@:noCompletion private var __graphic:Graphics;
	@:noCompletion private var __scale9Grid:Rectangle;
	@:noCompletion private var __scale9GridDirty:Bool = false;

	/**
	 * 不同的引擎中显示的原始对象引用
	 */
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
	 * 这将图像分为九个区域，其角落将始终保持其原始大小。中心区域在两个方向上延伸以填充剩余空间；侧部区域将相应地在水平或垂直方向上拉伸。
	 */
	public var scale9Grid(get, set):Rectangle;

	private function get_scale9Grid():Rectangle {
		if (__scale9Grid != null) {
			return __scale9Grid;
		}
		if (data != null) {
			return data.scale9Rect;
		}
		return null;
	}

	/**
	 * 获得九宫格图已渲染的图形
	 * @return Graphic
	 */
	private function getScale9GridGraphic():Graphics {
		var __scale9Grid = scale9Grid;
		if (__scale9Grid != null) {
			if (__graphic == null) {
				__graphic = new Graphics();
			}
			if (__scale9GridDirty) {
				__scale9GridDirty = false;
				__graphic.clear();
				// 这里仅继承坐标、旋转，但不要缩放，因为不需要
				__graphic.x = this.x;
				__graphic.y = this.y;
				__graphic.rotation = this.rotation;
				__graphic.__updateTransform(this.parent);
				__graphic.beginBitmapData(this.data);
				var rect = __scale9Grid;
				var rightWidth = (this.data.width - rect.x - rect.width);
				var leftWidth = rect.x;
				var topHeight = rect.y;
				var bottomHeight = (this.data.height - rect.y - rect.height);
				var textureWidth = this.data.data.getWidth();
				var textureHeight = this.data.data.getHeight();
				var offsetX = this.data.uvOffsetX;
				var offsetY = this.data.uvOffsetY;
				// 左上
				__graphic.drawRectUVs(0, 0, leftWidth, topHeight, maskUVs(0, 0, leftWidth, topHeight, textureWidth, textureHeight, offsetX, offsetY));
				// 右上
				__graphic.drawRectUVs(this.width - rightWidth, 0, rightWidth, topHeight,
					maskUVs(rect.right, 0, rightWidth, topHeight, textureWidth, textureHeight, offsetX, offsetY));
				// 左下
				__graphic.drawRectUVs(0, this.height - bottomHeight, leftWidth, bottomHeight,
					maskUVs(0, rect.bottom, leftWidth, bottomHeight, textureWidth, textureHeight, offsetX, offsetY));
				// 右下
				__graphic.drawRectUVs(this.width - rightWidth, this.height - bottomHeight, rightWidth, bottomHeight,
					maskUVs(rect.right, rect.bottom, rightWidth, bottomHeight, textureWidth, textureHeight, offsetX, offsetY));
				// 中间
				__graphic.drawRectUVs(rect.left, rect.top, this.width - rightWidth - rect.left, this.height - bottomHeight - rect.top,
					maskUVs(rect.x, rect.y, rect.width, rect.height, textureWidth, textureHeight, offsetX, offsetY));
				// 左边中间
				__graphic.drawRectUVs(0, topHeight, leftWidth, this.height - bottomHeight - topHeight,
					maskUVs(0, rect.y, leftWidth, rect.height, textureWidth, textureHeight, offsetX, offsetY));
				// 右边中间
				__graphic.drawRectUVs(this.width - rightWidth, topHeight, rightWidth, this.height - bottomHeight - topHeight,
					maskUVs(rect.right, rect.y, rightWidth, rect.height, textureWidth, textureHeight, offsetX, offsetY));
				// 上面中间
				__graphic.drawRectUVs(leftWidth, 0, width - leftWidth - rightWidth, topHeight,
					maskUVs(rect.x, 0, rect.width, topHeight, textureWidth, textureHeight, offsetX, offsetY));
				// 下面中间
				__graphic.drawRectUVs(leftWidth, height - bottomHeight, width - leftWidth - rightWidth, bottomHeight,
					maskUVs(rect.x, rect.bottom, rect.width, bottomHeight, textureWidth, textureHeight, offsetX, offsetY));
			}
		}
		return __graphic;
	}

	private function maskUVs(x:Float, y:Float, w:Float, h:Float, textureWidth:Float, textureHeight:Float, offsetX:Float, offsetY:Float):Array<Float> {
		x += offsetX;
		y += offsetY;
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
		__uvsDirty = true;
		this.setDirty();
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

	/**
	 * 更新tranform
	 * @param parent 如果提供了parent，则会根据parent更新worldTransform
	 */
	override private function __updateTransform(parent:DisplayObject):Void {
		if (parent != null) {
			this.__worldAlpha = parent.__worldAlpha * this.__alpha;
			// 世界矩阵
			this.__worldTransform.identity();
			if (this.data != null && this.data.frameRect != null) {
				this.__worldTransform.translate(-this.data.frameRect.x, -this.data.frameRect.y);
			}
			this.__worldTransform.translate(this.__originWorldX, this.__originWorldY);
			this.__worldTransform.concat(__transform);
			this.__worldTransform.concat(parent.__worldTransform);
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

	override private function get_width():Float {
		if (scale9Grid != null) {
			return __width;
		}
		return super.get_width();
	}

	override private function get_height():Float {
		if (scale9Grid != null) {
			return __height;
		}
		return super.get_height();
	}
}
