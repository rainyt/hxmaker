package hx.utils.inputs;

#if html5
import hx.events.Event;
import hx.geom.Point;
import hx.display.InputLabel;
import js.html.TextAreaElement;
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

	/**
	 * 打开输入
	 */
	public static function openInput(input:InputLabel):Void {
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
			textureArea.onkeyup = onKeyUp;
			// 侦听原生选区变化（如 Ctrl+A 全选），同步回引擎侧渲染高亮
			textureArea.onselect = onNativeSelect;
			Browser.document.getElementsByTagName("html")[0].appendChild(textureArea);
			// 侦听窗口变化
			Browser.document.onresize = onResize;
		}
		textureArea.value = input.data;
		textureArea.style.visibility = "visible";
		textureArea.selectionStart = input.selectionStart;
		textureArea.selectionEnd = input.selectionEnd;
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

	public static function onKeyUp():Void {
		input.selectionStart = textureArea.selectionStart;
		input.selectionEnd = textureArea.selectionEnd;
	}

	/**
	 * 原生输入框选区变化时（如 Ctrl+A 全选）同步回引擎侧，用于渲染选区高亮
	 */
	public static function onNativeSelect():Void {
		if (input == null)
			return;
		input.selectionStart = textureArea.selectionStart;
		input.selectionEnd = textureArea.selectionEnd;
	}

	/**
	 * 将引擎侧选区同步到隐藏输入框，让原生键盘获得删除/替换选区的能力
	 */
	public static function syncSelectionToNative(input:InputLabel):Void {
		if (HTML5TextInputUtils.input != input || textureArea == null)
			return;
		var start = input.selectionStart < input.selectionEnd ? input.selectionStart : input.selectionEnd;
		var end = input.selectionStart < input.selectionEnd ? input.selectionEnd : input.selectionStart;
		// 值相同时不写入，避免触发多余的 select 事件造成回环
		if (textureArea.selectionStart != start)
			textureArea.selectionStart = start;
		if (textureArea.selectionEnd != end)
			textureArea.selectionEnd = end;
	}

	/**
	 * 侦听输入
	 */
	public static function onInput():Void {
		if (input == null)
			return;
		// 先同步选区再同步文本：input.data 的 setter 内部会把当前选区回写到这里，
		// 若先改文本，过时的选区值会覆盖 textarea 刚更新的光标位置
		input.selectionStart = textureArea.selectionStart;
		input.selectionEnd = textureArea.selectionEnd;
		input.data = textureArea.value.substr(0, 9999);
		input.getTextWidth();
		input.dispatchEvent(new Event(Event.CHANGE));
	}

	/**
	 * 停止输入
	 */
	public static function closeInput(label:InputLabel):Void {
		if (label == input) {
			input = null;
			if (textureArea != null) {
				textureArea.style.visibility = "hidden";
				textureArea.blur();
			}
		}
	}
}
#end
