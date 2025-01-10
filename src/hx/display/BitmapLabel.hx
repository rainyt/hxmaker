package hx.display;

import hx.assets.Atlas;

/**
 * 纹理字符渲染
 */
class BitmapLabel extends Box implements IDataProider<String> {
	private var __text:String;
	private var __textDirty:Bool = false;

	/**
	 * 设置文本
	 */
	public var data(get, set):String;

	public function get_data():String {
		return __text;
	}

	public function set_data(value:String):String {
		__text = value;
		__textDirty = true;
		return value;
	}

	public function new() {
		super();
		this.updateEnabled = true;
	}

	private function __onUpdateText():Void {
		if (__textDirty) {
			// 重绘
			this.removeChildren();
			var w:Null<Float> = this.__width;
			if (__text != null && atlas != null) {
				var chars = __text.split("");
				var offestX = 0.;
				var offestY = 0.;
				for (i in 0...chars.length) {
					var c = chars[i];
					var img = new Image(atlas.bitmapDatas.get(c));
					this.addChild(img);
					img.x = offestX;
					img.y = offestY;
					if (img.data != null) {
						offestX += (img.width + space);
						if (w != null && offestX > w) {
							offestX = 0.;
							offestY += img.height;
						}
					} else {
						offestX += 10;
					}
				}
			}
			__textDirty = false;
		}
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		__onUpdateText();
	}

	/**
	 * 精灵图纹理
	 */
	public var atlas:Atlas;

	/**
	 * 字符的左右间距
	 */
	public var space(default, set):Float = 0;

	private function set_space(value:Float):Float {
		this.space = value;
		__textDirty = true;
		return value;
	}

	override function get_width():Float {
		__onUpdateText();
		return super.get_width();
	}

	override function get_height():Float {
		__onUpdateText();
		return super.get_height();
	}
}
