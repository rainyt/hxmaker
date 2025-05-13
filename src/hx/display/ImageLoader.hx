package hx.display;

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
		__data = v;
		if (__data is String) {
			new BitmapDataFuture(__data, true).onComplete((data) -> {
				if (__data == v)
					image.data = data;
			});
		} else if (__data is BitmapData) {
			image.data = __data;
		}
		return __data;
	}

	public var image:Image = new Image();

	public function new(data:Dynamic) {
		super();
		this.addChild(image);
	}

	override function set_width(value:Float):Float {
		image.width = value;
		return value;
	}

	override function set_height(value:Float):Float {
		image.height = value;
		return value;
	}
}
