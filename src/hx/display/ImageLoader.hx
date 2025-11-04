package hx.display;

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
		__data = v;
		if (__data is String) {
			var bitmapData = UIManager.getBitmapData(v);
			if (bitmapData != null) {
				image.data = bitmapData;
				this.dispatchEvent(new Event(Event.CHANGE));
			} else {
				new BitmapDataFuture(__data, true).onComplete((data) -> {
					if (__data == v) {
						image.data = data;
						this.dispatchEvent(new Event(Event.CHANGE));
					}
				});
			}
		} else if (__data is BitmapData) {
			image.data = __data;
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
}
