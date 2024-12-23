package hx.display;

import hx.events.MouseEvent;

/**
 * 按钮
 */
class Button extends DisplayObjectContainer {
	/**
	 * 按钮的容器
	 */
	private var __box:DisplayObjectContainer;

	/**
	 * 按钮的皮肤
	 */
	private var __img:Image;

	/**
	 * 文字渲染器
	 */
	private var __label:Label;

	/**
	 * 皮肤数据
	 */
	public var skin(default, set):ButtonSkin;

	/**
	 * 设置文本格式
	 */
	public var textFormat(get, set):TextFormat;

	private function get_textFormat():TextFormat {
		return this.__label.textFormat;
	}

	private function set_textFormat(value:TextFormat):TextFormat {
		this.__label.textFormat = value;
		return value;
	}

	/**
	 * 按钮点击事件
	 */
	public var clickEvent:Void->Void;

	private function set_skin(skin:ButtonSkin = null):ButtonSkin {
		this.skin = skin;
		__img.data = skin != null ? skin.up : null;
		__label.width = __img.width;
		__label.height = __img.height;
		return skin;
	}

	/**
	 * 设置按钮文本
	 */
	public var text(default, set):String;

	private function set_text(text:String):String {
		this.text = text;
		__label.data = text;
		return text;
	}

	public function new(text:String = null, skin:ButtonSkin = null) {
		super();
		__img = new Image();
		this.addChild(__img);
		__label = new Label(text);
		__label.horizontalAlign = CENTER;
		__label.verticalAlign = MIDDLE;
		this.addChild(__label);
		this.skin = skin;
		this.mouseChildren = false;
	}

	override function onStageInit() {
		super.onStageInit();
		this.addEventListener(MouseEvent.MOUSE_DOWN, this.onMouseEvent);
	}

	override function onAddToStage() {
		super.onAddToStage();
		this.stage.addEventListener(MouseEvent.MOUSE_UP, this.onMouseEvent);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, this.onMouseEvent);
	}

	private function onMouseEvent(e:MouseEvent) {
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				this.scaleX = 0.94;
				this.scaleY = 0.94;
				this.__originWorldX = this.width * 0.03;
				this.__originWorldY = this.height * 0.03;
			case MouseEvent.MOUSE_UP:
				this.scaleX = 1;
				this.scaleY = 1;
				this.__originWorldX = 0;
				this.__originWorldY = 0;
				if (e.target == this && clickEvent != null) {
					clickEvent();
				}
		}
	}
}
