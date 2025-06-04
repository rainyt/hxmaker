package hx.display;

import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.utils.TextInputUtils;
import hx.events.MouseEvent;

/**
 * 输入文本组件
 */
class InputLabel extends Box implements IDataProider<String> {
	public var line:Quad = new Quad(1, 1, 0xffffff);

	private var label:Label = new Label();

	public var data(get, set):String;

	private function set_data(value:String):String {
		this.label.data = value;
		return value;
	}

	private function get_data():String {
		return this.label.data;
	}

	public var textFormat(get, set):TextFormat;

	private function set_textFormat(value:TextFormat):TextFormat {
		this.label.textFormat = value;
		return value;
	}

	private function get_textFormat():TextFormat {
		return this.label.textFormat;
	}

	public function getTextWidth():Float {
		return this.label.getTextWidth();
	}

	public function getTextHeight():Float {
		return this.label.getTextHeight();
	}

	override function onInit() {
		super.onInit();
		this.updateEnabled = true;
		this.addEventListener(MouseEvent.CLICK, onClick);
		this.layout = new AnchorLayout();
		this.label.layoutData = AnchorLayoutData.fill();
		this.addChild(this.label);
	}

	private function onClick(event:MouseEvent):Void {
		// 触发点击事件时，设置焦点到输入框
		TextInputUtils.openInput(this);
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
	}
}
