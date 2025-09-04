package hx.utils;

import hx.events.Event;
import hx.geom.Point;
import hx.display.InputLabel;
import js.html.TextAreaElement;
import js.Browser;

class TextInputUtils {
	/**
	 * 输入框组件
	 */
	public static var textureArea:TextAreaElement;

	/**
	 * 当前焦点输入组件
	 */
	public static var zinput:InputLabel;

	/**
	 * 打开输入
	 */
	public static function openInput(input:InputLabel):Void {
		zinput = input;
		var point = input.localToGlobal(new Point(0, 0));
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
		textureArea.value = zinput.data;
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
		zinput.selectionStart = textureArea.selectionStart;
		zinput.selectionEnd = textureArea.selectionEnd;
	}

	/**
	 * 侦听输入
	 */
	public static function onInput():Void {
		if (zinput == null)
			return;
		zinput.data = textureArea.value.substr(0, 9999);
		zinput.getTextWidth();
		zinput.selectionStart = textureArea.selectionStart;
		zinput.selectionEnd = textureArea.selectionEnd;
		zinput.dispatchEvent(new Event(Event.CHANGE));
	}

	/**
	 * 停止输入
	 */
	public static function closeInput(label:InputLabel):Void {
		if (label == zinput) {
			zinput = null;
			if (textureArea != null) {
				textureArea.style.visibility = "hidden";
				textureArea.blur();
			}
		}
	}
}
