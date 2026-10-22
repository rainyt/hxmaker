package hx.utils.inputs;

#if html5
import hx.events.Event;
import hx.display.InputLabel;
import js.html.TextAreaElement;
import js.html.KeyboardEvent;
import js.html.InputEvent;
import js.Browser;

class HTML5TextInputUtils {
	/**
	 * 输入框组件
	 */
	public static var textureArea:TextAreaElement;

	/**
	 * 当前焦点输入组件
	 */
	public static var input:InputLabel;

	/** 输入法组合期间保留原生缓冲，确认后再提交和过滤。 */
	private static var __composing:Bool = false;

	/** 焦点导航需同时兼容浏览器未提供 isComposing 的组合输入事件。 */
	public static function isComposing():Bool {
		return input != null && __composing;
	}

	/**
	 * 打开输入
	 */
	public static function openInput(input:InputLabel):Void {
		if (HTML5TextInputUtils.input != input)
			__composing = false;
		HTML5TextInputUtils.input = input;
		if (textureArea == null) {
			textureArea = Browser.document.createTextAreaElement();
			textureArea.style.position = "absolute";
			textureArea.style.bottom = "0px";
			textureArea.style.left = "0px";
			textureArea.style.width = "100%";
			textureArea.style.height = "36px";
			textureArea.style.fontSize = "24px";
			// if (Lib.isPc())
			textureArea.style.zIndex = "-1";
			textureArea.oninput = onInput;
			textureArea.onkeydown = onKeyDown;
			textureArea.onkeyup = onKeyUp;
			textureArea.addEventListener("beforeinput", onBeforeInput);
			textureArea.addEventListener("compositionstart", onCompositionStart);
			textureArea.addEventListener("compositionend", onCompositionEnd);
			// 侦听原生选区变化（如 Ctrl+A 全选），同步回引擎侧渲染高亮
			textureArea.onselect = onNativeSelect;
			Browser.document.getElementsByTagName("html")[0].appendChild(textureArea);
			// 侦听窗口变化
			Browser.document.onresize = onResize;
		}
		textureArea.style.visibility = "visible";
		syncTextToNative(input);
		input.selectionAnchor = input.selectionEnd;
		textureArea.focus();
	}

	/**
	 * 窗口发生变化时，兼容Android的输入框会被挡的问题。
	 */
	public static function onResize():Void {
		if (Browser.navigator.userAgent.indexOf("Android") != -1) {
			Browser.window.addEventListener('resize', function() {
				if (Browser.document.activeElement.tagName == 'INPUT' || Browser.document.activeElement.tagName == 'TEXTAREA') {
					Browser.window.setTimeout(function() {
						untyped Browser.document.activeElement.scrollIntoViewIfNeeded();
					}, 0);
				}
			});
		}
	}

	/** 在原生编辑前拦截回车，保留当前选区；组合输入的确认键必须放行。 */
	public static function onKeyDown(event:KeyboardEvent):Void {
		if (input != null && !input.wordWrap && !__composing && !event.isComposing && event.keyCode != 229
			&& (event.key == "Enter" || event.keyCode == 13))
			event.preventDefault();
	}

	/** 补充移动键盘和直接编辑产生的换行，不拦截粘贴中的有效文字。 */
	public static function onBeforeInput(event:js.html.Event):Void {
		var type:String = Reflect.field(event, "inputType");
		if (input != null && !input.wordWrap && !__composing && Reflect.field(event, "isComposing") != true
			&& (type == "insertLineBreak" || type == "insertParagraph"))
			event.preventDefault();
	}

	public static function onCompositionStart(event:js.html.Event = null):Void {
		__composing = input != null;
	}

	public static function onCompositionEnd(event:js.html.Event = null):Void {
		__composing = false;
		onInput();
	}

	public static function onKeyUp(event:KeyboardEvent = null):Void {
		if (input != null && !__composing && (event == null || !event.isComposing))
			syncSelectionFromNative();
	}

	/**
	 * 原生输入框选区变化时（如 Ctrl+A 全选）同步回引擎侧，用于渲染选区高亮
	 */
	public static function onNativeSelect():Void {
		if (input == null || __composing)
			return;
		syncSelectionFromNative();
	}

	/** 反向选区的活动端在开头，滚动应跟随活动端。 */
	private static function syncSelectionFromNative():Void {
		var caret = textureArea.selectionDirection == "backward" ? textureArea.selectionStart : textureArea.selectionEnd;
		var previous = input.suspendNativeSync;
		input.suspendNativeSync = true;
		input.syncSelectionFromNative(textureArea.selectionStart, textureArea.selectionEnd, caret);
		input.suspendNativeSync = previous;
	}

	/**
	 * 将引擎侧选区同步到隐藏输入框，让原生键盘获得删除/替换选区的能力
	 */
	public static function syncSelectionToNative(input:InputLabel):Void {
		if (HTML5TextInputUtils.input != input || textureArea == null || __composing || input.suspendNativeSync)
			return;
		var start = input.selectionStart < input.selectionEnd ? input.selectionStart : input.selectionEnd;
		var end = input.selectionStart < input.selectionEnd ? input.selectionEnd : input.selectionStart;
		// 值相同时不写入，避免触发多余的 select 事件造成回环
		var direction = start == end ? "none" : @:privateAccess input.__caretIndex == start ? "backward" : "forward";
		if (textureArea.selectionStart != start || textureArea.selectionEnd != end || textureArea.selectionDirection != direction)
			textureArea.setSelectionRange(start, end, direction);
	}

	/** 清理后回写真实文本和选区，避免隐藏输入框保留换行或旧内容。 */
	public static function syncTextToNative(input:InputLabel):Void {
		if (HTML5TextInputUtils.input != input || textureArea == null || __composing || input.suspendNativeSync)
			return;
		var value = input.data == null ? "" : input.data;
		if (textureArea.value != value)
			textureArea.value = value;
		syncSelectionToNative(input);
	}

	/**
	 * 侦听输入
	 */
	public static function onInput(event:js.html.Event = null):Void {
		var nativeEvent:InputEvent = cast event;
		if (input == null || __composing || (nativeEvent != null && nativeEvent.isComposing))
			return;
		var raw = textureArea.value;
		var value = input.normalizeInputText(raw).substr(0, 9999);
		var start = Std.int(Math.min(value.length, input.getNormalizedInputIndex(raw, textureArea.selectionStart)));
		var end = Std.int(Math.min(value.length, input.getNormalizedInputIndex(raw, textureArea.selectionEnd)));
		var direction = textureArea.selectionDirection;
		var changed = input.data != value;
		// 先保存并映射原生选区，再更新文本；赋值 value 会收起原生选区。
		var previous = input.suspendNativeSync;
		input.suspendNativeSync = true;
		if (changed)
			input.data = value;
		if (textureArea.value != value) {
			textureArea.value = value;
			textureArea.setSelectionRange(start, end, direction);
		}
		input.syncSelectionFromNative(start, end, direction == "backward" ? start : end);
		input.suspendNativeSync = previous;
		if (changed) {
			input.getTextWidth();
			input.dispatchEvent(new Event(Event.CHANGE));
		}
	}

	/**
	 * 停止输入
	 */
	public static function closeInput(label:InputLabel):Void {
		if (label == input) {
			input = null;
			__composing = false;
			if (textureArea != null) {
				textureArea.style.visibility = "hidden";
				textureArea.blur();
			}
		}
	}
}
#end
