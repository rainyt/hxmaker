package hx.display;

import hx.geom.Point;
import hx.geom.Rectangle;
import hx.utils.SoundManager;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.events.MouseEvent;

/**
 * 按钮类，用于创建可点击的UI按钮
 * 支持文本、皮肤、点击音效等功能
 */
@:keep
class Button extends BoxContainer {
	/**
	 * 点击音效ID
	 * 设置后，所有按钮点击时都会播放此音效
	 */
	public static var clickSoundEffectId:String;

	/**
	 * 按钮的容器，用于放置额外的子元素
	 */
	private var __box:Box;

	/**
	 * 获取按钮的容器
	 * @return 按钮的容器对象
	 */
	public var container(get, never):Box;

	/**
	 * 获取按钮的容器
	 * @return 按钮的容器对象
	 */
	private function get_container():Box {
		return __box;
	}

	/**
	 * 按钮的皮肤图片
	 */
	private var __img:Image;

	/**
	 * 文字渲染器，用于显示按钮文本
	 */
	private var __label:Label;

	/**
	 * 设置文本偏移点
	 * 用于调整按钮文本的位置
	 */
	public var labelOffsetPoint(default, set):Point;

	/**
	 * 设置文本偏移点
	 * @param value 偏移点坐标
	 * @return 设置后的偏移点
	 */
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
	 * 用于设置按钮的外观
	 */
	public var skin(default, set):ButtonSkin;

	/**
	 * 设置文本格式
	 * 用于调整按钮文本的样式
	 */
	public var textFormat(get, set):TextFormat;

	/**
	 * 获取文本格式
	 * @return 当前文本格式
	 */
	private function get_textFormat():TextFormat {
		return this.__label.textFormat;
	}

	/**
	 * 设置文本格式
	 * @param value 要设置的文本格式
	 * @return 设置后的文本格式
	 */
	private function set_textFormat(value:TextFormat):TextFormat {
		this.__label.textFormat = value;
		return value;
	}

	/**
	 * 按钮点击事件
	 * 当按钮被点击时调用
	 */
	public var clickEvent:Void->Void;

	/**
	 * 设置按钮皮肤
	 * @param skin 皮肤数据
	 * @return 设置后的皮肤数据
	 */
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
	 * 用于显示按钮上的文字
	 */
	public var text(default, set):String;

	/**
	 * 设置按钮文本
	 * @param text 要设置的文本内容
	 * @return 设置后的文本内容
	 */
	private function set_text(text:String):String {
		this.text = text;
		__label.data = text;
		return text;
	}

	/**
	 * 构造一个按钮对象
	 * @param text 按钮文本，默认为null
	 * @param skin 按钮皮肤，默认为null
	 * @param textFormat 文本格式，默认为null
	 */
	public function new(text:String = null, skin:ButtonSkin = null, textFormat:TextFormat = null) {
		__img = new Image();
		__box = new Box();
		super();
		this.addChildAt(__img, 0);
		__label = new Label(text);
		__label.horizontalAlign = CENTER;
		__label.verticalAlign = MIDDLE;
		this.addChildAt(__box, 1);
		this.addChildAt(__label, 2);
		this.skin = skin;
		this.mouseChildren = false;
		this.layout = new AnchorLayout();
		__img.layoutData = AnchorLayoutData.fill();
		__label.layoutData = AnchorLayoutData.fill();
		this.textFormat = textFormat;
	}

	/**
	 * 当按钮添加到舞台时初始化
	 * 添加鼠标事件监听器
	 */
	override function onStageInit() {
		super.onStageInit();
		this.addEventListener(MouseEvent.MOUSE_DOWN, this.onMouseEvent);
		this.addEventListener(MouseEvent.CLICK, this.onMouseEvent);
	}

	/**
	 * 当按钮添加到舞台时调用
	 * 添加舞台级别的鼠标事件监听器
	 */
	override function onAddToStage() {
		super.onAddToStage();
		this.stage.addEventListener(MouseEvent.MOUSE_UP, this.onMouseEvent);
	}

	/**
	 * 当按钮从舞台移除时调用
	 * 移除舞台级别的鼠标事件监听器
	 */
	override function onRemoveToStage() {
		super.onRemoveToStage();
		this.stage.removeEventListener(MouseEvent.MOUSE_UP, this.onMouseEvent);
	}

	/**
	 * 按钮是否处于按下状态
	 */
	private var __isDown:Bool = false;

	/**
	 * 处理鼠标事件
	 * @param e 鼠标事件对象
	 */
	private function onMouseEvent(e:MouseEvent) {
		switch e.type {
			case MouseEvent.MOUSE_DOWN:
				__isDown = true;
				this.box.scale = 1;
				var pWidth = this.width;
				var pHeight = this.height;
				this.box.scale = 0.94;
				this.box.originX = pWidth * 0.03;
				this.box.originY = pHeight * 0.03;
				if (clickSoundEffectId != null) {
					SoundManager.getInstance().playEffect(clickSoundEffectId);
				}
			case MouseEvent.MOUSE_UP:
				this.box.scaleX = 1;
				this.box.scaleY = 1;
				this.box.originX = 0;
				this.box.originY = 0;
				__isDown = false;
			case MouseEvent.CLICK:
				if (clickEvent != null) {
					clickEvent();
				}
		}
	}

	/**
	 * 九宫格缩放区域
	 * 用于设置按钮皮肤的可缩放区域
	 */
	public var scale9Grid(get, set):Rectangle;

	/**
	 * 设置九宫格缩放区域
	 * @param value 缩放区域矩形
	 * @return 设置后的缩放区域
	 */
	private function set_scale9Grid(value:Rectangle):Rectangle {
		this.__img.scale9Grid = value;
		return value;
	}

	/**
	 * 获取九宫格缩放区域
	 * @return 当前缩放区域
	 */
	private function get_scale9Grid():Rectangle {
		return this.__img.scale9Grid;
	}

	/**
	 * 更新布局
	 * 当按钮未按下时更新布局
	 */
	override function updateLayout() {
		if (!__isDown) {
			super.updateLayout();
		}
	}
}
