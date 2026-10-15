package hx.display;

import hx.geom.Rectangle;
import hx.geom.Point;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.utils.TextInputUtils;
import hx.events.MouseEvent;
import hx.providers.ITextFieldLayoutProvider;
import StringTools;

/**
 * 输入文本组件
 */
class InputLabel extends Box implements IDataProider<String> {
	public var line:Quad = new Quad(1, 1, 0xffffff);

	public var label:Label = new Label();

	/** 视口固定，文字、选区和光标一起在内容容器内滚动。 */
	private var __viewport:Box = new Box();

	private var __content:Box = new Box();
	private var __clipRect:Rectangle = new Rectangle();
	private var __textBounds:Rectangle = new Rectangle();
	private var __selectionBounds:Rectangle = new Rectangle();
	private var __selectionQuadCount:Int = 0;
	private var __selectionQuads:Array<Quad> = [];
	private var __selectionDirty:Bool = true;
	private var __lastLayoutVersion:Int = -1;
	private var __lastMeasuredLabel:Label;
	private var __lastMeasuredData:String;
	private var __lastTextWidth:Float = -1;
	private var __lastTextHeight:Float = -1;
	private var __lastLabelOriginX:Float = Math.NaN;
	private var __lastLabelOriginY:Float = Math.NaN;
	private var __scrollX:Float = 0;
	private var __scrollY:Float = 0;
	private var __refreshingViewport:Bool = false;
	private var __dragStageX:Float = 0;
	private var __dragStageY:Float = 0;

	/** 是否允许多行输入；关闭后不接收回车和换行符。 */
	public var wordWrap(get, set):Bool;

	private function set_wordWrap(v:Bool):Bool {
		var changed = label.wordWrap != v;
		label.wordWrap = v;
		placeholderLabel.wordWrap = v;
		if (changed) {
			if (!v && normalizeInputText(__data) != __data)
				this.data = __data;
			TextInputUtils.syncTextToNative(this);
		}
		return v;
	}

	private function get_wordWrap():Bool {
		return label.wordWrap;
	}

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
		for (quad in __selectionQuads)
			quad.data = value;
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

	public var horizontalAlign(get, set):HorizontalAlign;

	private function set_horizontalAlign(value:HorizontalAlign):HorizontalAlign {
		this.label.horizontalAlign = value;
		this.placeholderLabel.horizontalAlign = value;
		return this.label.horizontalAlign;
	}

	private function get_horizontalAlign():HorizontalAlign {
		return this.label.horizontalAlign;
	}

	public var verticalAlign(get, set):VerticalAlign;

	private function set_verticalAlign(value:VerticalAlign):VerticalAlign {
		this.label.verticalAlign = value;
		this.placeholderLabel.verticalAlign = value;
		return this.label.verticalAlign;
	}

	private function get_verticalAlign():VerticalAlign {
		return this.label.verticalAlign;
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
	private var __caretRect:Rectangle = new Rectangle();

	private function updateSelection(caretIndex:Int = -1):Void {
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
			__caretIndex = caretIndex < 0 ? __selectionEnd : Std.int(Math.max(0, Math.min(length, caretIndex)));
		__dt = 0;
		__selectionDirty = true;
		// 将选区同步到原生输入通道（如 HTML5 的隐藏输入框），让原生键盘获得删除/替换选区的能力
		if (!suspendNativeSync)
			TextInputUtils.syncSelectionToNative(this);
	}

	/**
	 * 更新选区高亮的显示
	 */
	private function updateSelectionHighlight():Void {
		var count = 0;
		__selectionBounds.setTo(0, 0, 0, 0);
		var segment:Rectangle = null;
		if (__selectionEnd > __selectionStart && label.root != null) {
			var start = displayIndex(__selectionStart);
			var end = displayIndex(__selectionEnd);
			for (i in start...end) {
				var rect = label.root.getChatBounds(i);
				if (rect == null)
					rect = caretBounds(i);
				if (rect == null)
					continue;
				var right = rect.right;
				var next = caretBounds(i + 1);
				if (next != null && next.y == rect.y)
					right = Math.max(right, next.x);
				if (segment == null || segment.y != rect.y) {
					if (segment != null)
						setSelectionQuad(count++, segment);
					segment = new Rectangle(rect.x, rect.y, Math.max(1, right - rect.x), rect.height);
				} else {
					segment.width = Math.max(segment.right, right) - segment.x;
					segment.height = Math.max(segment.height, rect.height);
				}
			}
			if (segment != null)
				setSelectionQuad(count++, segment);
		}
		for (i in count...__selectionQuadCount)
			__selectionQuads[i].visible = false;
		__selectionQuadCount = count;
		__selectionDirty = false;
	}

	/** 复用每一行的高亮色块，兼容已有的 selectionQuad 属性。 */
	private function setSelectionQuad(index:Int, rect:Rectangle):Void {
		if (index == __selectionQuads.length) {
			var quad = new Quad(1, 1, selectionColor);
			quad.alpha = selectionQuad.alpha;
			quad.includeInLayout = false;
			__selectionQuads.push(quad);
			__content.addChildAt(quad, index);
		}
		var quad = __selectionQuads[index];
		quad.visible = true;
		quad.x = rect.x + label.x + label.originX;
		quad.y = rect.y + label.y + label.originY;
		quad.width = rect.width;
		quad.height = rect.height;
		__selectionBounds.expand(quad.x, quad.y, quad.width, quad.height);
	}

	/**
	 * 从原生输入通道一次性同步选区。
	 * 回读原生选区时必须用此方法：若逐步设置 selectionStart/selectionEnd，
	 * 第一步 setter 内部的选区回写会用另一个端点的旧值覆盖原生输入框刚建立的选区
	 * （例如 Ctrl+A 全选会被截断，导致删除后遗留最后一个字符）。
	 */
	public function syncSelectionFromNative(start:Int, end:Int, caretIndex:Int = -1):Void {
		__selectionStart = start;
		__selectionEnd = end;
		this.updateSelection(caretIndex);
	}

	private var __data:String = "";

	public var data(get, set):String;

	/** 所有输入入口共用约束，密码模式也先过滤原文。 */
	public function normalizeInputText(value:String):String {
		if (value == null || wordWrap || (value.indexOf("\r") < 0 && value.indexOf("\n") < 0))
			return value;
		return StringTools.replace(StringTools.replace(value, "\r", ""), "\n", "");
	}

	/** 将过滤前的插入位置映射到过滤后的文本，CRLF 的两个字符分别计数。 */
	public function getNormalizedInputIndex(value:String, index:Int):Int {
		if (value == null)
			return 0;
		var end = Std.int(Math.max(0, Math.min(value.length, index)));
		var result = end;
		if (!wordWrap && (value.indexOf("\r") >= 0 || value.indexOf("\n") >= 0)) {
			for (i in 0...end) {
				var code = StringTools.fastCodeAt(value, i);
				if (code == 13 || code == 10)
					result--;
			}
		}
		return result;
	}

	private function set_data(value:String):String {
		var normalized = normalizeInputText(value);
		var filtered = normalized != value;
		var caret = filtered ? getNormalizedInputIndex(value, __caretIndex) : -1;
		var anchor = filtered ? getNormalizedInputIndex(value, selectionAnchor) : 0;
		if (filtered) {
			__selectionStart = getNormalizedInputIndex(value, __selectionStart);
			__selectionEnd = getNormalizedInputIndex(value, __selectionEnd);
			__caretIndex = caret;
		}
		var previous = suspendNativeSync;
		suspendNativeSync = true;
		__data = normalized;
		this.updateLabelDisplay();
		this.updatePlaceholderVisibility();
		this.updateSelection(caret);
		this.selectionAnchor = filtered ? anchor : __selectionEnd;
		suspendNativeSync = previous;
		if (!previous)
			TextInputUtils.syncTextToNative(this);
		return __data;
	}

	private function get_data():String {
		return __data;
	}

	/**
	 * 更新默认提示文案的可见性
	 */
	private function updatePlaceholderVisibility():Void {
		this.placeholderLabel.visible = (this.label.data == null || this.label.data.length == 0)
			&& this.placeholder != null
			&& this.placeholder != "";
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
		passwordChar = value == null || value.length == 0 ? "*" : value;
		if (displayAsPassword) {
			this.updateLabelDisplay();
		}
		return passwordChar;
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
		__viewport.layoutData = AnchorLayoutData.fill();
		this.addChild(__viewport);
		__viewport.addChild(__content);
		__selectionQuads.push(selectionQuad);
		__content.addChild(selectionQuad);
		__content.addChild(placeholderLabel);
		__content.addChild(label);
		__content.addChild(line);
		selectionQuad.includeInLayout = false;
		line.includeInLayout = false;
		line.visible = false;
		// 空白位置同样可以获得焦点，输入框自身负责边界命中。
		this.mouseClickEnabled = true;
		this.mouseChildren = false;
		// 选区高亮默认隐藏，以半透明显示
		this.selectionQuad.visible = false;
		this.selectionQuad.alpha = 0.35;
		// 默认提示文案颜色
		placeholderLabel.color = 0x999999;
		__placeholderTextFormat.color = 0x999999;
		this.updatePlaceholderVisibility();
	}

	private var __isClicked = false;

	private function onMouseDown(event:MouseEvent):Void {
		__isClicked = false;
		__dragStageX = event.stageX;
		__dragStageY = event.stageY;
		// 按下即定位光标，并以此为锚点开始拖拽选区
		var index:Int = this.getCharIndexAtPoint(event.stageX, event.stageY);
		this.selectionAnchor = index;
		this.setSelectionCollapsed(index);
		// 按下就接入原生键盘。拖拽到文字或输入框外抬起时可能没有 CLICK，
		// 不能等 CLICK 才打开输入通道，否则选区虽然可见，却无法删除或替换。
		this.focus();
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
		__dragStageX = event.stageX;
		__dragStageY = event.stageY;
		this.setDragSelection(this.getCharIndexAtPoint(event.stageX, event.stageY));
	}

	private function onStageMouseUp(event:MouseEvent):Void {
		this.endDragSelection();
		// 在外部抬起也恢复键盘焦点，保留拖拽选区；浏览器可能在按下的默认动作中转移焦点。
		if (stage != null && stage.focus == this)
			this.focus();
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
		__selectionStart = start;
		__selectionEnd = end;
		this.updateSelection();
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
		__selectionStart = index;
		__selectionEnd = index;
		this.updateSelection();
	}

	/**
	 * 拖拽选区：以按下时的锚点为一端，当前移动位置为另一端
	 */
	private function setDragSelection(index:Int):Void {
		__caretIndex = index;
		__selectionStart = Std.int(Math.min(index, selectionAnchor));
		__selectionEnd = Std.int(Math.max(index, selectionAnchor));
		this.updateSelection(index);
	}

	/**
	 * 获得指定舞台坐标处的字符索引（光标应落在的位置）
	 */
	public function getCharIndexAtPoint(stageX:Float, stageY:Float):Int {
		refreshViewport(false);
		if (label.root == null)
			return 0;
		// 使用文本局部坐标，同时消除滚动、对齐、组件缩放和父节点变换的影响。
		var point = label.globalToLocal(new Point(stageX, stageY));
		var length = __data == null ? 0 : __data.length;
		var best = 0;
		var bestY = Math.POSITIVE_INFINITY;
		var bestX = Math.POSITIVE_INFINITY;
		for (i in 0...length + 1) {
			var rect = caretBounds(displayIndex(i));
			if (rect == null)
				continue;
			var dy = point.y < rect.y ? rect.y - point.y : point.y > rect.bottom ? point.y - rect.bottom : 0;
			var dx = Math.abs(point.x - rect.x);
			if (dy < bestY || (dy == bestY && dx < bestX)) {
				best = i;
				bestY = dy;
				bestX = dx;
			}
		}
		return best;
	}

	private var __isFocus:Bool = false;

	public function focus():Void {
		__isFocus = true;
		__isClicked = true;
		if (stage != null)
			stage.focus = this;
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
		var focused = stage != null && stage.focus == this;
		if (!focused) {
			if (__isFocus)
				this.deactivate();
			line.visible = false;
		}
		// 失焦的输入框和提示文案也需要裁剪。
		refreshViewport();
		if (__dragging && focused)
			updateDragScroll(dt);
		if (!focused)
			return;
		if (!line.visible) {
			if (__isClicked) {
				line.visible = true;
				this.updateLine(1);
			}
		} else {
			// 闪缩
			this.updateLine(__dt % 1 < 0.5 ? 1 : 0);
		}
		// 光标显隐可能改变边界，但闪烁透明度不应反复切换遮罩。
		updateClip();
	}

	private function updateLine(alpha:Float):Void {
		#if disable_label_line_style
		line.visible = false;
		#else
		var x = __caretRect.x + label.x + label.originX;
		var y = __caretRect.y + label.y + label.originY;
		if (line.x != x)
			line.x = x;
		if (line.y != y)
			line.y = y;
		if (line.height != __caretRect.height)
			line.height = __caretRect.height;
		if (line.alpha != alpha)
			line.alpha = alpha;
		#end
	}

	/** 保留自动尺寸行为，内部视口的缓存尺寸不参与文本自然尺寸的计算。 */
	override function get_width():Float {
		return __width == null ? Math.max(label.getTextWidth(), placeholderLabel.visible ? placeholderLabel.getTextWidth() : 0) : __width;
	}

	override function get_height():Float {
		return __height == null ? Math.max(label.getTextHeight(), placeholderLabel.visible ? placeholderLabel.getTextHeight() : 0) : __height;
	}

	override public function updateLayout():Void {
		super.updateLayout();
		var width = Math.max(0, __viewport.width);
		var height = Math.max(0, __viewport.height);
		if (__content.width != width)
			__content.width = width;
		if (__content.height != height)
			__content.height = height;
		if (__width == null) {
			@:privateAccess label.__width = null;
			@:privateAccess placeholderLabel.__width = null;
		} else {
			if (label.width != width)
				label.width = width;
			if (placeholderLabel.width != width)
				placeholderLabel.width = width;
		}
		if (label.height != height)
			label.height = height;
		if (placeholderLabel.height != height)
			placeholderLabel.height = height;
	}

	/** 先消费祖先的布局变更，避免按旧宽度测量文字或查询光标。 */
	private function ensureLayout(object:DisplayObjectContainer):Void {
		if (object.parent != null)
			ensureLayout(object.parent);
		@:privateAccess object.__updateLayout();
	}

	private function displayIndex(index:Int):Int {
		return displayAsPassword ? index * passwordChar.length : index;
	}

	/** 优先使用插入位置接口；其他后端仍可使用原有字符边界。 */
	private function caretBounds(index:Int):Rectangle {
		if (Std.isOfType(label.root, ITextFieldLayoutProvider))
			return cast(label.root, ITextFieldLayoutProvider).getCaretBounds(index);
		if (label.root == null)
			return null;
		var rect = label.root.getChatBounds(index);
		if (rect != null)
			return new Rectangle(rect.x, rect.y, 1, rect.height);
		if (index > 0) {
			var previous = label.root.getChatBounds(index - 1);
			if (previous != null)
				return new Rectangle(previous.right, previous.y, 1, previous.height);
		}
		return new Rectangle(0, 0, 1, label.fontSize + 2);
	}

	/** 文本布局只在发生变动时扫描；静止输入框每帧仅比较缓存状态。 */
	private function refreshViewport(followCaret:Bool = true):Void {
		if (__refreshingViewport)
			return;
		__refreshingViewport = true;
		ensureLayout(this);
		var dirty = @:privateAccess label.__textFormatDirty;
		label.getTextWidth();
		label.getTextHeight();
		if (__viewport.width != width || __viewport.height != height)
			updateLayout();
		@:privateAccess label.updateAlignTranform();
		var active = placeholderLabel.visible ? placeholderLabel : label;
		dirty = dirty || @:privateAccess active.__textFormatDirty;
		var textWidth = active.getTextWidth();
		var textHeight = active.getTextHeight();
		@:privateAccess active.updateAlignTranform();
		var provider:ITextFieldLayoutProvider = Std.isOfType(active.root, ITextFieldLayoutProvider) ? cast active.root : null;
		var version = provider == null ? -1 : provider.layoutVersion;
		if (dirty || __lastMeasuredLabel != active || __lastMeasuredData != active.data || __lastLayoutVersion != version || __lastTextWidth != textWidth
			|| __lastTextHeight != textHeight) {
			__textBounds.setTo(0, 0, textWidth, textHeight);
			if (provider != null) {
				var bounds = provider.getTextBounds();
				__textBounds.setTo(bounds.x, bounds.y, bounds.width, bounds.height);
			} else if (active.root != null) {
				for (i in 0...active.data.length) {
					var rect = active.root.getChatBounds(i);
					if (rect != null)
						__textBounds.expand(rect.x, rect.y, rect.width, rect.height);
				}
			}
			__lastMeasuredLabel = active;
			__lastMeasuredData = active.data;
			__lastLayoutVersion = version;
			__lastTextWidth = textWidth;
			__lastTextHeight = textHeight;
			__selectionDirty = true;
		}
		if (__lastLabelOriginX != label.x + label.originX || __lastLabelOriginY != label.y + label.originY) {
			__lastLabelOriginX = label.x + label.originX;
			__lastLabelOriginY = label.y + label.originY;
			__selectionDirty = true;
		}
		var caret = caretBounds(displayIndex(__caretIndex));
		if (caret != null)
			__caretRect.setTo(caret.x, caret.y, caret.width, caret.height);
		if (__selectionDirty)
			updateSelectionHighlight();
		var width = Math.max(0, __viewport.width);
		var height = Math.max(0, __viewport.height);
		var right = __textBounds.right + active.x + active.originX;
		var bottom = __textBounds.bottom + active.y + active.originY;
		var focused = stage != null && stage.focus == this;
		if (focused && !placeholderLabel.visible) {
			right = Math.max(right, __caretRect.right + label.x + label.originX);
			bottom = Math.max(bottom, __caretRect.bottom + label.y + label.originY);
		}
		__scrollX = Math.max(0, Math.min(__scrollX, Math.max(0, right - width)));
		__scrollY = Math.max(0, Math.min(__scrollY, Math.max(0, bottom - height)));
		if (followCaret && focused && width > 0 && height > 0) {
			var x = __caretRect.x + label.x + label.originX;
			var y = __caretRect.y + label.y + label.originY;
			if (x < __scrollX)
				__scrollX = Math.max(0, x);
			else if (x + line.width > __scrollX + width)
				__scrollX = x + line.width - width;
			if (y < __scrollY)
				__scrollY = Math.max(0, y);
			else if (y + __caretRect.height > __scrollY + height)
				__scrollY = y + __caretRect.height - height;
		}
		applyScroll();
		updateLine(line.alpha);
		updateClip();
		__refreshingViewport = false;
	}

	private function applyScroll():Void {
		if (__content.x != -__scrollX)
			__content.x = -__scrollX;
		if (__content.y != -__scrollY)
			__content.y = -__scrollY;
	}

	/** 只对越界的可见内容启用矩形裁剪；复用矩形并在尺寸变化时标脏。 */
	private function updateClip():Void {
		var active = placeholderLabel.visible ? placeholderLabel : label;
		var x = __textBounds.x + active.x + active.originX - __scrollX;
		var y = __textBounds.y + active.y + active.originY - __scrollY;
		var right = x + __textBounds.width;
		var bottom = y + __textBounds.height;
		var overflow = __textBounds.width > 0 && (x < 0 || y < 0 || right > __viewport.width || bottom > __viewport.height);
		if (line.visible && stage != null && stage.focus == this)
			overflow = overflow
				|| line.x - __scrollX < 0
				|| line.y - __scrollY < 0
				|| line.x + line.width - __scrollX > __viewport.width
				|| line.y + line.height - __scrollY > __viewport.height;
		if (__selectionQuadCount > 0)
			overflow = overflow
				|| __selectionBounds.x - __scrollX < 0
				|| __selectionBounds.y - __scrollY < 0
				|| __selectionBounds.right - __scrollX > __viewport.width
				|| __selectionBounds.bottom - __scrollY > __viewport.height;
		if (overflow) {
			var width = Math.max(0, __viewport.width);
			var height = Math.max(0, __viewport.height);
			if (__clipRect.width != width || __clipRect.height != height) {
				__clipRect.setTo(0, 0, width, height);
				@:privateAccess __viewport.setDirty();
			}
			__viewport.maskRect = __clipRect;
		} else {
			__viewport.maskRect = null;
		}
	}

	/** 鼠标停在视口外时继续滚动，支持选择当前看不到的字符。 */
	private function updateDragScroll(dt:Float):Void {
		var point = __viewport.globalToLocal(new Point(__dragStageX, __dragStageY));
		var dx = point.x < 0 ? point.x : point.x > __viewport.width ? point.x - __viewport.width : 0;
		var dy = point.y < 0 ? point.y : point.y > __viewport.height ? point.y - __viewport.height : 0;
		if (dx == 0 && dy == 0)
			return;
		var maxX = Math.max(0, __textBounds.right + label.originX + line.width - __viewport.width);
		var maxY = Math.max(0, __textBounds.bottom + label.originY - __viewport.height);
		__scrollX = Math.max(0, Math.min(maxX, __scrollX + Math.max(-400, Math.min(400, dx * 6)) * dt));
		__scrollY = Math.max(0, Math.min(maxY, __scrollY + Math.max(-400, Math.min(400, dy * 6)) * dt));
		applyScroll();
		var edge = __viewport.localToGlobal(new Point(Math.max(0, Math.min(__viewport.width, point.x)), Math.max(0, Math.min(__viewport.height, point.y))));
		setDragSelection(getCharIndexAtPoint(edge.x, edge.y));
		refreshViewport();
	}
}
