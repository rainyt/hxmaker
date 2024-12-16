package hx.displays;

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
}
