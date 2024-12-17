package hx.displays;

import hx.gemo.Rectangle;
import hx.providers.ITextFieldDataProvider;
import hx.providers.IRootDataProvider;

/**
 * 文本渲染器
 */
class Label extends DisplayObject implements IDataProider<String> implements IRootDataProvider<ITextFieldDataProvider> {
	@:noCompletion private var __data:String;
	@:noCompletion private var __textFormat:TextFormat = new TextFormat();

	public var root(get, set):ITextFieldDataProvider;

	@:noCompletion private function get_root():ITextFieldDataProvider {
		return __root;
	}

	@:noCompletion private function set_root(value:ITextFieldDataProvider):ITextFieldDataProvider {
		this.__root = value;
		this.updateAlignTranform();
		return __root;
	}

	/**
	 * 文本内容
	 */
	public var data(get, set):String;

	private function set_data(value:String):String {
		__data = value;
		return __data;
	}

	private function get_data():String {
		return __data;
	}

	/**
	 * 文本格式
	 */
	public var textFormat(get, set):TextFormat;

	private function get_textFormat():TextFormat {
		return __textFormat.clone();
	}

	private function set_textFormat(value:TextFormat):TextFormat {
		__textFormat.setTo(value);
		setDirty();
		return value;
	}

	public function new(?text:String) {
		super();
		this.data = text;
		this.width = 200;
		this.height = 36;
	}

	override function __updateTransform(parent:DisplayObject) {
		super.__updateTransform(parent);
		this.updateAlignTranform();
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
					__worldY = (this.height - this.root.getTextHeight()) / 2;
				case BOTTOM:
					__worldY = this.height - this.root.getTextHeight();
			}
			switch __horizontalAlign {
				case LEFT:
				case CENTER:
					__worldX = (this.width - this.root.getTextWidth()) / 2;
				case RIGHT:
					__worldX = (this.width - this.root.getTextWidth());
			}
		}
	}

	override function __getRect():Rectangle {
		__rect.x = 0;
		__rect.y = 0;
		__rect.width = this.width;
		__rect.height = this.height;
		return super.__getRect();
	}
}
