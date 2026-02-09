package hx.utils.inputs;

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
			Browser.document.getElementsByTagName("html")[0].appendChild(textureArea);
			// 侦听窗口变化
			Browser.document.onresize = onResize;
		}
		textureArea.value = input.data;
		textureArea.style.visibility = "visible";
		textureArea.selectionStart = input.selectionStart;
		textureArea.selectionEnd = input.selectionEnd;
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
	 * 侦听输入
	 */
	public static function onInput():Void {
		if (input == null)
			return;
		input.data = textureArea.value.substr(0, 9999);
		input.getTextWidth();
		input.selectionStart = textureArea.selectionStart;
		input.selectionEnd = textureArea.selectionEnd;
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
