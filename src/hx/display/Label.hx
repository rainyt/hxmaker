package hx.display;

import hx.filters.StrokeFilter;
#if openfl
import hx.shader.StrokeShader;
#end
import hx.core.Hxmaker;
import hx.geom.Matrix;
import hx.geom.Rectangle;
import hx.providers.ITextFieldDataProvider;
import hx.providers.IRootDataProvider;

/**
 * 文本渲染器
 */
@:keep
class Label extends DisplayObject implements IDataProider<String> implements IRootDataProvider<ITextFieldDataProvider> {
	/**
	 * 设置文本缓存器
	 */
	public static function setTextFieldContextBitmapData(textCacheId:Int, bitmapData:TextCacheBitmapData):Void {
		#if hxmaker_openfl
		hx.render.TextFieldRender.setTextFieldContextBitmapData(textCacheId,
			new hx.text.TextFieldContextBitmapData(bitmapData.size, bitmapData.textureWidth, bitmapData.textureHeight, bitmapData.offestX, bitmapData.offestY));
		#end
	}

	/**
	 * 释放文本缓存器
	 */
	public static function disposeTextFieldContextBitmapData(textCacheId:Int):Void {
		#if hxmaker_openfl
		hx.render.TextFieldRender.disposeTextFieldContextBitmapData(textCacheId);
		#end
	}

	/**
	 * 全局文本过滤实现
	 */
	public static var onGlobalCharFilter:String->String;

	public var __smoothing:Bool = true;

	/**
	 * 文本缓存ID，默认为`0`，用于决定使用哪个文本缓存器。如果需要使用多个文本缓存器，你需要检查`引擎后端`是否支持。当前`openfl`后端能够正常使用，请参考例子：
	 * ```haxe
	 * Label.setTextFieldContextBitmapData(1, new TextCacheBitmapData(50, 2048, 2048, 5, 5));
	 * ```
	 * 如果不设置则也会有一个默认的文本缓存器，请注意内存的使用率，每多一个文本缓存器，则意味着增加了一张2048的图片；
	 */
	public var textCacheId:Int = 0;

	@:privateAccess private var __textFormatDirty:Bool = true;

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
	 * 是否启用全局文本过滤
	 */
	public var charFilterEnabled:Bool = true;

	@:noCompletion private var __data:String;
	@:noCompletion private var __textFormat:TextFormat = new TextFormat();

	public var root(get, set):ITextFieldDataProvider;

	@:noCompletion private function get_root():ITextFieldDataProvider {
		return __root;
	}

	@:noCompletion private function set_root(value:ITextFieldDataProvider):ITextFieldDataProvider {
		this.__root = value;
		return __root;
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		// if (root != null)
		// this.root.release();
	}

	/**
	 * 文本内容
	 */
	public var data(get, set):String;

	private function set_data(value:String):String {
		if (__data != value) {
			__data = value;
			this.setDirty();
			this.setFilterDirty();
		}
		return __data;
	}

	private function get_data():String {
		return __data;
	}

	/**
	 * 文本格式
	 */
	public var textFormat(get, set):TextFormat;

	/**
	 * 范围文本格式
	 */
	private var __rangeTextFormats:Array<RangeTextFormat> = [];

	/**
	 * 设置文本格式范围
	 * @param textFormat 
	 * @param startIndex 
	 * @param length 
	 */
	public function setRangeTextFormat(textFormat:TextFormat, startIndex:Int = 0, length:Int = -1):Void {
		var rangeTextFormat:RangeTextFormat = new RangeTextFormat();
		rangeTextFormat.setTo(textFormat);
		rangeTextFormat.startIndex = startIndex;
		rangeTextFormat.endIndex = startIndex + length;
		__rangeTextFormats.push(rangeTextFormat);
	}

	/**
	 * 清空所有范围文本格式
	 */
	public function clearRangeTextFormats():Void {
		__rangeTextFormats = [];
	}

	/**
	 * 根据字符索引获取文本格式
	 * @param at 字符索引
	 * @return 范围文本格式
	 */
	public function getCharTextFormatAt(at:Int):TextFormat {
		for (format in __rangeTextFormats) {
			if (format.startIndex <= at && at < format.endIndex) {
				return format;
			}
		}
		return __textFormat;
	}

	/**
	 * 根据正则表达式设置文本范围格式
	 */
	public function setRegexRangeTextFormat(regex:EReg, textFormat:TextFormat, overrideSet:Bool = true):Void {
		if (overrideSet)
			this.clearRangeTextFormats();
		var text:String = this.data;
		var texts:Array<String> = [];
		regex.map(text, (f) -> {
			var value = f.matched(0);
			texts.push(value);
			return value;
		});
		if (texts.length > 0) {
			this.setTextsRangeTextFormat(texts, textFormat, false);
		}
	}

	/**
	 * 设置文本列表中的文本格式设置
	 * @param texts 
	 * @param textFormat 
	 * @param overrideSet 
	 */
	public function setTextsRangeTextFormat(texts:Array<String>, textFormat:TextFormat, overrideSet:Bool = true):Void {
		if (overrideSet)
			this.clearRangeTextFormats();
		var text:String = this.data;
		for (s in texts) {
			var at = text.indexOf(s);
			if (at != -1) {
				this.setRangeTextFormat(textFormat, at, s.length);
			}
		}
	}

	/**
	 * 是否自动换行，默认为`true`
	 */
	public var wordWrap(get, set):Bool;

	private var __wordWrap:Bool = true;

	private function set_wordWrap(value:Bool):Bool {
		if (__wordWrap != value) {
			__wordWrap = value;
			this.setDirty();
		}
		return __wordWrap;
	}

	private function get_wordWrap():Bool {
		return __wordWrap;
	}

	private function get_textFormat():TextFormat {
		return __textFormat.clone();
	}

	private function set_textFormat(value:TextFormat):TextFormat {
		if (value == null)
			return null;
		__textFormat.setTo(value);
		this.setTextFormatDirty();
		return value;
	}

	/**
	 * 设置脏标记，并且强制重新渲染文本
	 * @param value 
	 */
	public function setTextFormatDirty(value:Bool = true):Void {
		this.__textFormatDirty = value;
		if (__textFormat != null) {
			if (__filter != null) {
				__filter.fontColor = __textFormat.color;
			}
		}
		this.setDirty();
	}

	/**
	 * 设置文本颜色，该接口与`textFormat`直接设置是一样的效果，只是更加方便快捷
	 */
	public var color(get, set):Int;

	private function set_color(value:Int):Int {
		if (__textFormat.color != value) {
			__textFormat.color = value;
			this.setTextFormatDirty();
		}
		return value;
	}

	/**
	 * 字体大小，该接口与`textFormat`直接设置是一样的效果，只是更加方便快捷
	 */
	public var fontSize(get, set):Int;

	private function set_fontSize(value:Int):Int {
		if (__textFormat.size != value) {
			__textFormat.size = value;
			this.setTextFormatDirty();
		}
		return value;
	}

	private function get_fontSize():Int {
		return __textFormat.size;
	}

	private function get_color():Int {
		return __textFormat.color;
	}

	public function new(?text:String, ?textFormat:TextFormat) {
		super();
		this.data = text;
		if (textFormat != null)
			this.textFormat = textFormat;
	}

	override function __updateTransform(parent:DisplayObject) {
		this.updateAlignTranform();
		super.__updateTransform(parent);
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

	/**
	 * 更新对齐位置
	 */
	private function updateAlignTranform():Void {
		if (root != null) {
			switch __verticalAlign {
				case TOP:
				case MIDDLE:
					__originWorldY = (this.height - Math.min(this.height, this.root.getTextHeight())) / 2;
				case BOTTOM:
					__originWorldY = (this.height - Math.min(this.height, this.root.getTextHeight()));
			}
			switch __horizontalAlign {
				case LEFT:
				case CENTER:
					__originWorldX = (this.width - Math.min(this.width, this.root.getTextWidth())) / 2;
				case RIGHT:
					__originWorldX = (this.width - Math.min(this.width, this.root.getTextWidth()));
			}
		}
	}

	override function __getRect():Rectangle {
		// __rect.x = -__originWorldX;
		// __rect.y = -__originWorldY;
		if (__width == null)
			__rect.width = getTextWidth();
		else
			__rect.width = __width;
		if (__height == null)
			__rect.height = getTextHeight();
		else
			__rect.height = __height;
		return __rect;
	}

	// override function getBounds(parent:Matrix = null):Rectangle {
	// 	if (parent != null) {
	// 		var t = parent.clone();
	// 		t.concat(__transform);
	// 		return __getLocalBounds(new Rectangle(0, 0, this.width, this.height), t);
	// 	} else {
	// 		return __getLocalBounds(new Rectangle(0, 0, this.width, this.height));
	// 	}
	// }

	public function getTextWidth():Float {
		if (__dirty) {
			Hxmaker.engine.renderer.renderLabel(this, true);
		}
		return root == null ? 0 : root.getTextWidth();
	}

	public function getTextHeight():Float {
		if (root == null && this.stage != null) {
			Hxmaker.engine.renderer.renderLabel(this, true);
		}
		return root == null ? 0 : root.getTextHeight();
	}

	override function setTransformDirty(value:Bool = true) {
		super.setTransformDirty(value);
	}

	override function get_width():Float {
		if (__width == null)
			return getTextWidth();
		return super.get_width();
	}

	override function get_height():Float {
		if (__height == null) {
			return getTextHeight();
		}
		return super.get_height();
	}

	private var __filter:StrokeFilter;

	/**
	 * 设置描边，当设置描边后，shader会变更
	 * @param color 
	 * @param size 
	 */
	public function stroke(color:Int = 0x0, size:Int = 1):Void {
		#if openfl
		__filter = new StrokeFilter(size, color, textFormat != null ? textFormat.color : 0x0);
		this.filters = [__filter];
		#end
	}
}
