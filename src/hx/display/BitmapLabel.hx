package hx.display;

import hx.geom.ColorTransform;
import hx.assets.FntAtlas;
import hx.assets.Atlas;

/**
 * 位图文本类，使用精灵图来渲染文本
 * 支持自定义字体、自动换行和对齐方式
 */
class BitmapLabel extends Box implements IDataProider<String> {
	/**
	 * 文本内容的内部存储
	 */
	private var __text:String;
	/**
	 * 文本是否需要更新的标记
	 */
	private var __textDirty:Bool = false;

	/**
	 * 设置文本内容
	 * @return 当前文本内容
	 */
	public var data(get, set):String;

	/**
	 * 获取当前文本内容
	 * @return 当前文本内容
	 */
	private function get_data():String {
		return __text;
	}

	/**
	 * 设置文本内容
	 * @param value 要设置的文本内容
	 * @return 设置后的文本内容
	 */
	private function set_data(value:String):String {
		if (__text == value)
			return value;
		__text = value;
		__textDirty = true;
		return value;
	}

	/**
	 * 构造一个位图文本显示对象
	 * @param atlas 精灵图，包含字体纹理
	 */
	public function new(?atlas:Atlas) {
		super();
		this.atlas = atlas;
		this.updateEnabled = true;
	}

	/**
	 * 设置颜色变换
	 * @param value 颜色变换对象
	 * @return 设置后的颜色变换对象
	 */
	override function set_colorTransform(value:ColorTransform):ColorTransform {
		__textDirty = true;
		return super.set_colorTransform(value);
	}

	/**
	 * 更新文本显示
	 * 当文本内容、字体、颜色等发生变化时调用
	 */
	private function __onUpdateText():Void {
		if (__textDirty) {
			// 重绘文本
			this.removeChildren();
			var w:Null<Float> = this.__width;
			if (__text != null && atlas != null) {
				var chars = __text.split("");
				var offestX = 0.;
				var offestY = 0.;
				var charFnt:FntChar = null;
				__textWidth = 0;
				__textHeight = 0;
				var fntAtlas:FntAtlas = (atlas is FntAtlas) ? cast atlas : null;
				for (i in 0...chars.length) {
					var c = chars[i];
					charFnt = null;
					var img = new Image(atlas.bitmapDatas.get(fontName + c));
					img.colorTransform = this.colorTransform;
					this.addChild(img);
					if (fntAtlas != null) {
						charFnt = fntAtlas.chars.get(c);
					}
					if (charFnt != null) {
						img.x = offestX + charFnt.xoffset;
						img.y = offestY + charFnt.yoffset;
					} else {
						img.x = offestX;
						img.y = offestY;
					}
					if (img.data != null) {
						if (charFnt != null)
							offestX += charFnt.xadvance;
						else
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

	/**
	 * 每帧更新
	 * @param dt 时间间隔，单位为秒
	 */
	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		__onUpdateText();
	}

	/**
	 * 精灵图纹理，包含字体的所有字符
	 */
	public var atlas:Atlas;

	/**
	 * 字符的左右间距
	 */
	public var space(default, set):Float = 0;

	/**
	 * 字体名称前缀，用于从精灵图中获取对应字符
	 */
	public var fontName:String = "";

	/**
	 * 设置字符间距
	 * @param value 字符间距值
	 * @return 设置后的字符间距值
	 */
	private function set_space(value:Float):Float {
		this.space = value;
		__textDirty = true;
		return value;
	}

	/**
	 * 是否允许自动换行，默认为`false`
	 */
	public var warpWord(default, set):Bool = false;

	/**
	 * 设置是否自动换行
	 * @param value 是否自动换行
	 * @return 设置后的自动换行状态
	 */
	private function set_warpWord(value:Bool):Bool {
		this.warpWord = value;
		__textDirty = true;
		return value;
	}

	/**
	 * 获取宽度
	 * @return 文本的宽度
	 */
	override function get_width():Float {
		__onUpdateText();
		return super.get_width();
	}

	/**
	 * 获取高度
	 * @return 文本的高度
	 */
	override function get_height():Float {
		__onUpdateText();
		return super.get_height();
	}

	/**
	 * 横向对齐方式
	 */
	public var horizontalAlign(get, set):HorizontalAlign;

	/**
	 * 横向对齐方式的内部存储
	 */
	private var __horizontalAlign:HorizontalAlign;

	/**
	 * 获取横向对齐方式
	 * @return 当前横向对齐方式
	 */
	private function get_horizontalAlign():HorizontalAlign {
		return __horizontalAlign;
	}

	/**
	 * 设置横向对齐方式
	 * @param value 要设置的横向对齐方式
	 * @return 设置后的横向对齐方式
	 */
	private function set_horizontalAlign(value:HorizontalAlign):HorizontalAlign {
		__horizontalAlign = value;
		this.setTransformDirty();
		return value;
	}

	/**
	 * 竖向对齐方式
	 */
	public var verticalAlign(get, set):VerticalAlign;

	/**
	 * 竖向对齐方式的内部存储
	 */
	private var __verticalAlign:VerticalAlign;

	/**
	 * 获取竖向对齐方式
	 * @return 当前竖向对齐方式
	 */
	private function get_verticalAlign():VerticalAlign {
		return __verticalAlign;
	}

	/**
	 * 设置竖向对齐方式
	 * @param value 要设置的竖向对齐方式
	 * @return 设置后的竖向对齐方式
	 */
	private function set_verticalAlign(value:VerticalAlign):VerticalAlign {
		__verticalAlign = value;
		this.setTransformDirty();
		return value;
	}

	/**
	 * 更新变换矩阵
	 * @param parent 父显示对象
	 */
	override function __updateTransform(parent:DisplayObject) {
		__onUpdateText();
		this.updateAlignTranform();
		super.__updateTransform(parent);
	}

	/**
	 * 更新对齐位置
	 * 根据设置的对齐方式调整文本的位置
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

	/**
	 * 文本宽度的内部存储
	 */
	private var __textWidth:Float = 0;
	/**
	 * 文本高度的内部存储
	 */
	private var __textHeight:Float = 0;

	/**
	 * 获取文本的实际宽度
	 * @return 文本的实际宽度
	 */
	public function getTextWidth():Float {
		__onUpdateText();
		return __textWidth;
	}

	/**
	 * 获取文本的实际高度
	 * @return 文本的实际高度
	 */
	public function getTextHeight():Float {
		__onUpdateText();
		return __textHeight;
	}
}
