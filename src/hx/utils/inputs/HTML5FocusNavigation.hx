package hx.utils.inputs;

#if (html5 && !wechat)
import hx.display.Stage;
import hx.display.ITabFocusable;
import hx.events.Keyboard;
import hx.events.KeyboardEvent;
import hx.utils.KeyboardTools;
import js.Browser;

/** 将浏览器中的 Tab 交给当前接口焦点所在的舞台，统一处理原生和引擎事件。 */
class HTML5FocusNavigation {
	private static var __initialized:Bool = false;

	public static function init():Void {
		if (__initialized || Browser.window == null || !Reflect.isFunction(Reflect.field(Browser.window, "addEventListener")))
			return;
		__initialized = true;
		// 捕获阶段先接管，避免隐藏输入框与 OpenFL 后端重复处理同一次 Tab。
		Browser.window.addEventListener("keydown", onKeyDown, true);
	}

	/** 页面中的其他原生编辑控件不使用引擎的 Tab 导航。 */
	public static function isExternalEditorFocused():Bool {
		var active = Browser.document.activeElement;
		return active != null && active != HTML5TextInputUtils.textureArea
			&& (active.tagName == "INPUT" || active.tagName == "TEXTAREA" || Reflect.field(active, "isContentEditable") == true);
	}

	private static function onKeyDown(event:js.html.KeyboardEvent):Void {
		if (event.key != "Tab" && event.keyCode != Keyboard.TAB)
			return;
		var current = @:privateAccess Stage.__focus;
		if (current == null || current.stage == null || current.isDisposed || !(current is ITabFocusable))
			return;
		// 页面中其他原生编辑控件已有焦点时，保留它们自己的 Tab 行为。
		if (isExternalEditorFocused())
			return;
		var engineEvent = new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, true);
		engineEvent.keyCode = Keyboard.TAB;
		engineEvent.shiftKey = event.shiftKey;
		engineEvent.ctrlKey = event.ctrlKey;
		engineEvent.altKey = event.altKey;
		engineEvent.metaKey = event.metaKey;
		engineEvent.isComposing = event.isComposing || event.keyCode == 229 || HTML5TextInputUtils.isComposing();
		if (event.defaultPrevented)
			engineEvent.preventDefault();
		event.stopImmediatePropagation();
		current.stage.handleKeyboardEvent(engineEvent);
		if (engineEvent.isDefaultPrevented)
			event.preventDefault();
		// 与后端原有顺序一致：事件分发结束后更新按键状态。
		@:privateAccess KeyboardTools.onKeyDown(Keyboard.TAB);
	}
}
#end
