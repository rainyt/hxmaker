package hx.display;

import hx.geom.Rectangle;
import hx.geom.ColorTransform;
import hx.events.Event;
import hx.ui.UIManager;
import hx.assets.BitmapDataFuture;

/**
 * 带有异步实现的图片显示对象
 */
class ImageLoader extends Box implements IDataProider<Dynamic> {
	private var __data:Dynamic;

	public var data(get, set):Dynamic;

	public function get_data():Dynamic {
		return __data;
	}

	public function set_data(v:Dynamic):Dynamic {
		if (__data == v)
			return v;
		__data = v;
		if (__data is String) {
			var bitmapData = UIManager.getBitmapData(v);
			if (bitmapData != null) {
				image.data = bitmapData;
				updateScale();
				this.dispatchEvent(new Event(Event.CHANGE));
			} else {
				new BitmapDataFuture(__data, true).onComplete((data) -> {
					if (__data == v) {
						image.data = data;
						updateScale();
						this.dispatchEvent(new Event(Event.CHANGE));
					}
				});
			}
		} else if (__data is BitmapData) {
			image.data = __data;
			updateScale();
			this.dispatchEvent(new Event(Event.CHANGE));
		}
		return __data;
	}

	public var image:Image = new Image();

	public function new(data:Dynamic = null) {
		super();
		this.addChild(image);
		if (data != null)
			this.data = data;
	}

	override function set_width(value:Float):Float {
		image.width = value;
		return value;
	}

	override function set_height(value:Float):Float {
		image.height = value;
		return value;
	}

	/**
	 * 图片的宽度缩放比例，默认值为null
	 */
	public var scaleWidth(default, set):Null<Float>;

	public function set_scaleWidth(value:Null<Float>):Null<Float> {
		this.scaleWidth = value;
		this.updateScale();
		return value;
	}

	/**
	 * 图片的高度缩放比例，默认值为null
	 */
	public var scaleHeight(default, set):Null<Float>;

	public function set_scaleHeight(value:Null<Float>):Null<Float> {
		this.scaleHeight = value;
		this.updateScale();
		return value;
	}

	private function updateScale() {
		if (this.image.data == null || this.scaleWidth == null || this.scaleHeight == null) {
			this.parent?.updateLayout();
			return;
		}
		var w = scaleWidth / this.image.data.width;
		var h = scaleHeight / this.image.data.height;
		this.scale = Math.min(w, h);
		this.parent?.updateLayout();
	}

	override function set_colorTransform(value:ColorTransform):ColorTransform {
		if (this.image != null)
			this.image.colorTransform = value;
		return super.set_colorTransform(value);
	}

	/**
	 * 九宫格缩放矩形，会根据矩形的left/right/top/bottom的值来裁剪位图，并拉伸填充。
	 * 这将图像分为九个区域，其角落将始终保持其原始大小。中心区域在两个方向上延伸以填充剩余空间；侧部区域将相应地在水平或垂直方向上拉伸。
	 */
	public var scale9Grid(get, set):Rectangle;

	private function get_scale9Grid():Rectangle {
		return image.scale9Grid;
	}

	private function set_scale9Grid(value:Rectangle):Rectangle {
		image.scale9Grid = value;
		return value;
	}
}
