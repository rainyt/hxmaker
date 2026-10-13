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
	 * 选区高亮色块，渲染在文本底层
	 */
	public var selectionQuad:Quad = new Quad(1, 1, 0x3399ff);

	/**
	 * 选区高亮颜色
	 */
	public var selectionColor(default, set):UInt = 0x3399ff;

	private function set_selectionColor(value:UInt):UInt {
		selectionColor = value;
		selectionQuad.data = value;
		return value;
	}

	/**
	 * 默认提示文案
	 */
	public var placeholder(default, set):String = "";

	/**
	 * 是否以密码模式显示文本（显示为密码掩码字符）
	 */
	public var displayAsPassword(default, set):Bool = false;

	/**
	 * 密码模式下的掩码字符，默认为"*"
	 */
	public var passwordChar(default, set):String = "*";

	/**
	 * 默认提示文案文本格式
	 */
	public var placeholderTextFormat(get, set):TextFormat;

	private var __placeholderTextFormat:TextFormat = new TextFormat();

	/**
	 * 当前选中的起始位置（始终小于等于 selectionEnd）
	 */
	public var selectionStart(get, set):Int;

	private function get_selectionStart():Int {
		return __selectionStart;
	}

	private function set_selectionStart(value:Int):Int {
		__selectionStart = value;
		this.updateSelection();
		return value;
	}

	/**
	 * 当前选中的结束位置
	 */
	public var selectionEnd(get, set):Int;

	private function get_selectionEnd():Int {
		return __selectionEnd;
	}

	private function set_selectionEnd(value:Int):Int {
		__selectionEnd = value;
		this.updateSelection();
		return value;
	}

	private var __selectionStart:Int = 0;

	private var __selectionEnd:Int = 0;

	/**
	 * 拖拽选区的锚点位置（鼠标按下时固定的一端）
	 */
	public var selectionAnchor:Int = 0;

	/**
	 * 光标位置（拖拽选区时跟随移动端，常规状态下与 selectionEnd 一致）
	 */
	private var __caretIndex:Int = 0;

	/**
	 * 是否正在拖拽选区
	 */
	private var __dragging:Bool = false;

	/**
	 * 是否挂起选区向原生输入通道的回写。
	 * 原生通道主动更新文本期间必须挂起：此时选区与文本都在过渡态，
	 * 回写会用旧值覆盖原生输入框刚设置的光标
	 */
	public var suspendNativeSync:Bool = false;

	/**
	 * 光标所在字符的边界
	 */
	private var __caretRect:Rectangle;

	private function updateSelection():Void {
		// 规范化选区：保证 selectionStart <= selectionEnd 且都在文本范围内
		var length:Int = __data != null ? __data.length : 0;
		var start:Int = __selectionStart;
		var end:Int = __selectionEnd;
		if (start > end) {
			var temp:Int = start;
			start = end;
			end = temp;
		}
		if (start < 0)
			start = 0;
		if (end > length)
			end = length;
		if (start > length)
			start = length;
		if (end < 0)
			end = 0;
		__selectionStart = start;
		__selectionEnd = end;
		if (__caretIndex < 0)
			__caretIndex = 0;
		if (__caretIndex > length)
			__caretIndex = length;
		if (!__dragging)
			__caretIndex = __selectionEnd;
		if (this.label.root != null)
			__caretRect = this.label.root.getChatBounds(__caretIndex);
		__dt = 0;
		this.updateSelectionHighlight();
		// 将选区同步到原生输入通道（如 HTML5 的隐藏输入框），让原生键盘获得删除/替换选区的能力
		if (!suspendNativeSync)
			TextInputUtils.syncSelectionToNative(this);
	}

	/**
	 * 更新选区高亮的显示
	 */
	private function updateSelectionHighlight():Void {
		var hasSelection:Bool = __selectionEnd > __selectionStart && this.label.root != null;
		if (!hasSelection) {
			this.selectionQuad.visible = false;
			return;
		}
		var startRect:Rectangle = this.label.root.getChatBounds(__selectionStart);
		var endRect:Rectangle = this.label.root.getChatBounds(__selectionEnd - 1);
		if (startRect == null || endRect == null) {
			this.selectionQuad.visible = false;
			return;
		}
		this.selectionQuad.visible = true;
		this.selectionQuad.x = startRect.x + @:privateAccess this.label.__originWorldX;
		this.selectionQuad.y = startRect.y + @:privateAccess this.label.__originWorldY;
		this.selectionQuad.width = (endRect.x + endRect.width) - startRect.x;
		this.selectionQuad.height = startRect.height > endRect.height ? startRect.height : endRect.height;
	}

	/**
	 * 从原生输入通道一次性同步选区。
	 * 回读原生选区时必须用此方法：若逐步设置 selectionStart/selectionEnd，
	 * 第一步 setter 内部的选区回写会用另一个端点的旧值覆盖原生输入框刚建立的选区
	 * （例如 Ctrl+A 全选会被截断，导致删除后遗留最后一个字符）。
	 */
	public function syncSelectionFromNative(start:Int, end:Int):Void {
		__selectionStart = start;
		__selectionEnd = end;
		this.updateSelection();
	}

	private var __data:String = "";

	public var data(get, set):String;

	private function set_data(value:String):String {
		__data = value;
		this.updateLabelDisplay();
		this.updatePlaceholderVisibility();
		// 文本变化后收拢锚点，并校正选区范围（选区可能超出新文本长度）
		this.selectionAnchor = this.selectionEnd;
		this.updateSelection();
		return value;
	}

	private function get_data():String {
		return __data;
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

	private function set_displayAsPassword(value:Bool):Bool {
		displayAsPassword = value;
		this.updateLabelDisplay();
		return value;
	}

	private function set_passwordChar(value:String):String {
		passwordChar = value;
		if (displayAsPassword) {
			this.updateLabelDisplay();
		}
		return value;
	}

	/**
	 * 更新Label的显示文本（根据密码模式决定显示实际文本还是掩码字符）
	 */
	private function updateLabelDisplay():Void {
		if (displayAsPassword && __data != null && __data.length > 0) {
			var masked = "";
			for (i in 0...__data.length) {
				masked += passwordChar;
			}
			this.label.data = masked;
		} else {
			this.label.data = __data;
		}
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
		this.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		this.addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClick);
		this.layout = new AnchorLayout();
		this.label.layoutData = AnchorLayoutData.fill();
		this.placeholderLabel.layoutData = AnchorLayoutData.fill();
		this.addChild(this.selectionQuad);
		this.addChild(this.placeholderLabel);
		this.addChild(this.label);
		this.addChild(line);
		this.mouseChildren = false;
		// 选区高亮默认隐藏，以半透明显示
		this.selectionQuad.visible = false;
		this.selectionQuad.alpha = 0.35;
		// 默认提示文案颜色
		this.placeholderTextFormat.color = 0x999999;
		this.updatePlaceholderVisibility();
	}

	private var __isClicked = false;

	private function onMouseDown(event:MouseEvent):Void {
		__isClicked = false;
		// 按下即定位光标，并以此为锚点开始拖拽选区
		var index:Int = this.getCharIndexAtPoint(event.stageX, event.stageY);
		this.selectionAnchor = index;
		this.setSelectionCollapsed(index);
		__dragging = true;
		// 在舞台上侦听移动/抬起，鼠标移出输入框后仍可继续扩展选区
		if (this.stage != null) {
			this.stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
			this.stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		}
	}

	private function onStageMouseMove(event:MouseEvent):Void {
		if (!__dragging)
			return;
		this.setDragSelection(this.getCharIndexAtPoint(event.stageX, event.stageY));
	}

	private function onStageMouseUp(event:MouseEvent):Void {
		this.endDragSelection();
	}

	/**
	 * 结束拖拽选区
	 */
	private function endDragSelection():Void {
		__dragging = false;
		if (this.stage != null) {
			this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
			this.stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
		}
	}

	private function onClick(event:MouseEvent):Void {
		__isClicked = true;
		this.focus();
	}

	/**
	 * 双击选中光标附近的单词
	 */
	private function onDoubleClick(event:MouseEvent):Void {
		if (__data == null || __data.length == 0)
			return;
		var index:Int = this.getCharIndexAtPoint(event.stageX, event.stageY);
		if (index >= __data.length)
			index = __data.length - 1;
		var start:Int = index;
		var end:Int = index + 1;
		if (isWordChar(StringTools.fastCodeAt(__data, index))) {
			while (start > 0 && isWordChar(StringTools.fastCodeAt(__data, start - 1)))
				start--;
			while (end < __data.length && isWordChar(StringTools.fastCodeAt(__data, end)))
				end++;
		}
		selectionAnchor = start;
		__caretIndex = end;
		this.selectionStart = start;
		this.selectionEnd = end;
		__isClicked = true;
	}

	/**
	 * 判断字符是否属于单词字符（英文字母、数字、下划线及 CJK 表意文字）
	 */
	private static function isWordChar(code:Int):Bool {
		return (code >= 48 && code <= 57) // 数字
			|| (code >= 65 && code <= 90) // 大写字母
			|| (code >= 97 && code <= 122) // 小写字母
			|| code == 95 // 下划线
			|| (code >= 0x3040 && code <= 0x30FF) // 日文假名
			|| (code >= 0x4E00 && code <= 0x9FFF); // CJK 统一表意文字
	}

	/**
	 * 将光标移动到指定位置（收起选区）
	 */
	private function setSelectionCollapsed(index:Int):Void {
		__caretIndex = index;
		this.selectionStart = index;
		this.selectionEnd = index;
	}

	/**
	 * 拖拽选区：以按下时的锚点为一端，当前移动位置为另一端
	 */
	private function setDragSelection(index:Int):Void {
		__caretIndex = index;
		if (index < this.selectionAnchor) {
			this.selectionStart = index;
			this.selectionEnd = this.selectionAnchor;
		} else {
			this.selectionStart = this.selectionAnchor;
			this.selectionEnd = index;
		}
	}

	/**
	 * 获得指定舞台坐标处的字符索引（光标应落在的位置）
	 */
	public function getCharIndexAtPoint(stageX:Float, stageY:Float):Int {
		var movePoint = this.globalToLocal(new Point(stageX, stageY));
		var text:String = this.label.data != null ? this.label.data : "";
		var charRect:Rectangle = new Rectangle();
		for (i in 0...text.length) {
			var rect = this.label.root.getChatBounds(i);
			if (rect == null) {
				continue;
			}
			rect.transform(charRect, @:privateAccess this.label.__worldTransform);
			if (charRect.containsPoint(stageX, stageY)) {
				if (movePoint.x - rect.x < rect.width / 2) {
					// 如果点击位置在字符左边，则光标在左边
					return i;
				} else {
					// 如果点击位置在字符右边，则光标在右边
					return i + 1;
				}
			}
		}
		// 未命中任何字符：按文本中点判断光标落在开头还是结尾
		return movePoint.x < this.getTextWidth() / 2 ? 0 : text.length;
	}

	private var __isFocus:Bool = false;

	public function focus():Void {
		__isFocus = true;
		TextInputUtils.openInput(this);
	}

	/**
	 * 取消输入焦点：关闭输入通道并收起选区
	 */
	private function deactivate():Void {
		__isFocus = false;
		this.endDragSelection();
		// 收起选区（光标停在原 selectionEnd 处），选区高亮随之隐藏
		this.setSelectionCollapsed(__selectionEnd);
		if (TextInputUtils.input == this)
			TextInputUtils.closeInput(this);
	}

	override function onRemoveToStage() {
		super.onRemoveToStage();
		if (__isFocus && TextInputUtils.input == this)
			TextInputUtils.closeInput(this);
		__isFocus = false;
		this.endDragSelection();
	}

	private var __dt:Float = 0;

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		__dt += dt;
		if (stage == null || stage.focus != this) {
			// 失焦后关闭输入通道（如 HTML5 的隐藏输入框），避免按键继续误入
			if (__isFocus)
				this.deactivate();
			if (line.visible)
				line.visible = false;
			return;
		}
		if (!line.visible) {
			if (__isClicked) {
				line.visible = true;
				this.updateLine(1);
			}
		} else {
			// 闪缩
			this.updateLine(__dt % 1 < 0.5 ? 1 : 0);
		}
		// 每帧刷新选区高亮，覆盖文本布局延迟导致的位置过期
		if (__selectionEnd > __selectionStart)
			this.updateSelectionHighlight();
	}

	private function updateLine(alpha:Float):Void {
		#if disable_label_line_style
		line.visible = false;
		#else
		line.x = __caretRect == null ? (__caretIndex == 0 ? 0 : getTextWidth() + 1) : __caretRect.x;
		line.height = __caretRect == null ? textFormat.size + 2 : __caretRect.height;
		line.alpha = alpha;
		line.x += @:privateAccess label.__originWorldX;
		if (__caretRect != null) {
			line.y = __caretRect.y;
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
	}
}
