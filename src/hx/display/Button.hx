package hx.display;

import hx.gemo.Point;
import hx.gemo.Rectangle;
import hx.utils.SoundManager;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.events.MouseEvent;

/**
 * 按钮
 */
class Button extends Box {
	/**
	 * 点击音效ID
	 */
	public static var clickSoundEffectId:String;

	/**
	 * 按钮的容器
	 */
	private var __box:Box;

	public var container(get, never):Box;

	private function get_container():Box {
		return __box;
	}

	/**
	 * 按钮的皮肤
	 */
	private var __img:Image;

	/**
	 * 文字渲染器
	 */
	private var __label:Label;

	/**
	 * 设置文本偏移点
	 */
	public var labelOffsetPoint(default, set):Point;

	private function set_labelOffsetPoint(value:Point):Point {
		labelOffsetPoint = value;
		var layoutData:AnchorLayoutData = cast __label.layoutData;
		layoutData.right = layoutData.left = layoutData.top = layoutData.bottom = 0;
		if (value.x < 0)
			layoutData.right = -value.x;
		else {
			layoutData.left = value.x;
		}
		if (value.y < 0)
			layoutData.bottom = -value.y;
		else {
			layoutData.top = value.y;
		}
		__label.layoutData = layoutData;
		return value;
	}

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
		this.width = __img.width;
		this.height = __img.height;
		__box.width = __img.width;
		__box.height = __img.height;
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
		__box = new Box();
		this.addChild(__box);
		this.skin = skin;
		this.mouseChildren = false;
		this.layout = new AnchorLayout();
		// __box.layoutData = AnchorLayoutData.fill();
		__img.layoutData = AnchorLayoutData.fill();
		__label.layoutData = AnchorLayoutData.fill();
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

	private var __isDown:Bool = false;

	private function onMouseEvent(e:MouseEvent) {
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				__isDown = true;
				this.scaleX = 0.94;
				this.scaleY = 0.94;
				this.originX = this.width * 0.03;
				this.originY = this.height * 0.03;
				if (clickSoundEffectId != null) {
					SoundManager.getInstance().playEffect(clickSoundEffectId);
				}
			case MouseEvent.MOUSE_UP:
				this.scaleX = 1;
				this.scaleY = 1;
				this.originX = 0;
				this.originY = 0;
				if (__isDown && e.target == this && clickEvent != null) {
					clickEvent();
				}
				__isDown = false;
		}
	}

	public var scale9Grid(get, set):Rectangle;

	private function set_scale9Grid(value:Rectangle):Rectangle {
		this.__img.scale9Grid = value;
		return value;
	}

	private function get_scale9Grid():Rectangle {
		return this.__img.scale9Grid;
	}
}
