package hx.display;

import hx.geom.Rectangle;
import hx.geom.Point;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.utils.TextInputUtils;
import hx.events.MouseEvent;
import StringTools;

/**
 * 输入文本组件
 */
class InputLabel extends Box implements IDataProider<String> {
	public var line:Quad = new Quad(1, 1, 0xffffff);

	public var label:Label = new Label();

	/**
	 * 默认提示文案Label
	 */
	public var placeholderLabel:Label = new Label();

	/**
	 * 默认提示文案
	 */
	public var placeholder(default, set):String = "";

	/**
	 * 默认提示文案文本格式
	 */
	public var placeholderTextFormat(get, set):TextFormat;

	private var __placeholderTextFormat:TextFormat = new TextFormat();

	/**
	 * 当前选中的起始位置
	 */
	public var selectionStart(default, set):Int = 0;

	private function set_selectionStart(value:Int):Int {
		selectionStart = value;
		this.updateSelection();
		return value;
	}

	/**
	 * 当前选中的结束位置
	 */
	public var selectionEnd(default, set):Int = 0;

	private function set_selectionEnd(value:Int):Int {
		selectionEnd = value;
		this.updateSelection();
		return value;
	}

	private var __startRect:Rectangle;

	private function updateSelection():Void {
		if (this.label.root != null)
			__startRect = this.label.root.getChatBounds(selectionStart);
		__dt = 0;
	}

	public var data(get, set):String;

	private function set_data(value:String):String {
		this.label.data = value;
		this.updatePlaceholderVisibility();
		return value;
	}

	private function get_data():String {
		return this.label.data;
	}

	/**
	 * 更新默认提示文案的可见性
	 */
	private function updatePlaceholderVisibility():Void {
		this.placeholderLabel.visible = (this.label.data == null || StringTools.trim(this.label.data) == "") && this.placeholder != "";
	}

	public var textFormat(get, set):TextFormat;

	private function set_textFormat(value:TextFormat):TextFormat {
		this.label.textFormat = value;
		return value;
	}

	private function get_textFormat():TextFormat {
		return this.label.textFormat;
	}

	/**
	 * 设置默认提示文案
	 */
	private function set_placeholder(value:String):String {
		placeholder = value;
		placeholderLabel.data = value;
		this.updatePlaceholderVisibility();
		return value;
	}

	/**
	 * 获取默认提示文案文本格式
	 */
	private function get_placeholderTextFormat():TextFormat {
		return __placeholderTextFormat;
	}

	/**
	 * 设置默认提示文案文本格式
	 */
	private function set_placeholderTextFormat(value:TextFormat):TextFormat {
		__placeholderTextFormat = value;
		placeholderLabel.textFormat = value;
		return value;
	}

	public function getTextWidth():Float {
		return this.label.getTextWidth();
	}

	public function getTextHeight():Float {
		return this.label.getTextHeight();
	}

	override function onInit() {
		super.onInit();
		this.label.charFilterEnabled = false;
		this.updateEnabled = true;
		this.addEventListener(MouseEvent.CLICK, onClick);
		this.layout = new AnchorLayout();
		this.label.layoutData = AnchorLayoutData.fill();
		this.placeholderLabel.layoutData = AnchorLayoutData.fill();
		this.addChild(this.placeholderLabel);
		this.addChild(this.label);
		this.addChild(line);
		this.mouseChildren = false;
		// 默认提示文案颜色
		this.placeholderTextFormat.color = 0x999999;
		this.updatePlaceholderVisibility();
	}

	private function onClick(event:MouseEvent):Void {
		// 确定光标位置
		var movePoint = this.globalToLocal(new Point(event.stageX, event.stageY));
		this.selectionStart = this.selectionEnd = this.label.data.length;
		var charRect:Rectangle = new Rectangle();
		for (i in 0...this.label.data.length) {
			var rect = this.label.root.getChatBounds(i);
			if (rect == null) {
				continue;
			}
			rect.transform(charRect, @:privateAccess this.label.__worldTransform);
			if (charRect.containsPoint(event.stageX, event.stageY)) {
				if (movePoint.x - rect.x < rect.width / 2) {
					// 如果点击位置在字符左边，则光标在左边
					this.selectionStart = this.selectionEnd = i;
				} else {
					// 如果点击位置在字符右边，则光标在右边
					this.selectionStart = this.selectionEnd = i + 1;
				}
				break;
			}
		}
		this.focus();
	}

	private var __isFocus:Bool = false;

	public function focus():Void {
		__isFocus = true;
		TextInputUtils.openInput(this);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		if (__isFocus && TextInputUtils.input == this)
			TextInputUtils.closeInput(this);
	}

	private var __dt:Float = 0;

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		__dt += dt;
		if (!line.visible) {
			if (stage.focus == this) {
				line.visible = true;
				this.updateLine(1);
			}
		} else if (line.visible) {
			if (stage.focus != this) {
				line.visible = false;
			} else {
				// 闪缩
				this.updateLine(__dt % 1 < 0.5 ? 1 : 0);
			}
		}
	}

	private function updateLine(alpha:Float):Void {
		#if disable_label_line_style
		line.visible = false;
		#else
		line.x = __startRect == null ? (selectionStart == 0 ? 0 : getTextWidth() + 1) : __startRect.x;
		line.height = __startRect == null ? textFormat.size + 2 : __startRect.height;
		line.alpha = alpha;
		line.x += @:privateAccess label.__originWorldX;
		if (__startRect != null) {
			line.y = __startRect.y;
			line.y += @:privateAccess label.__originWorldY;
		} else {
			switch label.verticalAlign {
				case BOTTOM:
					line.y = this.height - textFormat.size + 2;
				case MIDDLE:
					line.y = (this.height - textFormat.size + 2) / 2;
				case TOP:
					line.y = 0;
			}
		}
		#end
		// line.y = __startRect == null ? 0 : __startRect.y;
	}
}
