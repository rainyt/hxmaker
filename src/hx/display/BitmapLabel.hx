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
		if (__text == value)
			return value;
		__text = value;
		__textDirty = true;
		return value;
	}

	/**
	 * 构造一个位图纹理显示对象
	 * @param atlas 精灵图
	 */
	public function new(?atlas:Atlas) {
		super();
		this.atlas = atlas;
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
				__textWidth = 0;
				__textHeight = 0;
				for (i in 0...chars.length) {
					var c = chars[i];
					var img = new Image(atlas.bitmapDatas.get(fontName + c));
					this.addChild(img);
					img.x = offestX;
					img.y = offestY;
					if (img.data != null) {
						offestX += (img.width + space);
						if (warpWord && w != null && offestX > w) {
							offestX = 0.;
							offestY += img.height;
						}
					} else {
						offestX += 10;
					}
					if (img.x + img.width > __textWidth) {
						__textWidth = img.x + img.width;
					}
					if (img.y + img.height > __textHeight) {
						__textHeight = img.y + img.height;
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

	/**
	 * 字符名称
	 */
	public var fontName:String = "";

	private function set_space(value:Float):Float {
		this.space = value;
		__textDirty = true;
		return value;
	}

	/**
	 * 是否允许自动换行，默认为`false`
	 */
	public var warpWord(default, set):Bool = false;

	private function set_warpWord(value:Bool):Bool {
		this.warpWord = value;
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

	/**
	 * 横向对齐方式
	 */
	public var horizontalAlign(get, set):HorizontalAlign;

	private var __horizontalAlign:HorizontalAlign;

	private function get_horizontalAlign():HorizontalAlign {
		return __horizontalAlign;
	}

	private function set_horizontalAlign(value:HorizontalAlign):HorizontalAlign {
		__horizontalAlign = value;
		this.setTransformDirty();
		return value;
	}

	/**
	 * 竖向对齐方式
	 */
	public var verticalAlign(get, set):VerticalAlign;

	private var __verticalAlign:VerticalAlign;

	private function get_verticalAlign():VerticalAlign {
		return __verticalAlign;
	}

	private function set_verticalAlign(value:VerticalAlign):VerticalAlign {
		__verticalAlign = value;
		this.setTransformDirty();
		return value;
	}

	override function __updateTransform(parent:DisplayObject) {
		__onUpdateText();
		this.updateAlignTranform();
		super.__updateTransform(parent);
	}

	/**
	 * 更新对齐位置
	 */
	private function updateAlignTranform():Void {
		switch __verticalAlign {
			case TOP:
			case MIDDLE:
				if (__height != null)
					__originWorldY = (this.__height - this.getTextHeight()) / 2;
			case BOTTOM:
				if (__height != null)
					__originWorldY = (this.__height - this.getTextHeight());
		}
		switch __horizontalAlign {
			case LEFT:
			case CENTER:
				if (__width != null)
					__originWorldX = (this.__width - this.getTextWidth()) / 2;
			case RIGHT:
				if (__width != null)
					__originWorldX = (this.__width - this.getTextWidth());
		}
	}

	private var __textWidth:Float = 0;
	private var __textHeight:Float = 0;

	public function getTextWidth():Float {
		__onUpdateText();
		return __textWidth;
	}

	public function getTextHeight():Float {
		__onUpdateText();
		return __textHeight;
	}
}
