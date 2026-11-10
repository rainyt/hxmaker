package hx.utils.inputs;

#if (html5 && !wechat)
import hx.core.Hxmaker;
import hx.display.Stage;
import hx.display.ITabFocusable;
import hx.events.Keyboard;
import hx.events.KeyboardEvent;
import hx.utils.KeyboardTools;
import js.Browser;

/** 将浏览器中的 Tab 交给当前接口焦点所在的舞台，统一处理原生和引擎事件。 */
class HTML5FocusNavigation {
	private static var __initialized:Bool = false;

	/**
	 * [ABN-PATCH 2026-10-25 / 2026-11-10 重放] 非浏览器宿主（hxnodejs 下跑同一份 html5 构建做无头自检）
	 * 没有全局 `window`；而 `Browser.window` 会被编成**裸全局名 `window`** ⇒ 直接判空就先抛
	 * `ReferenceError: window is not defined`，根本走不到判空。必须用 `typeof` 守卫。
	 *
	 * ⚠ 这是**本仓库对引擎的本地补丁**（上游 `24b8062` 原版没有它）。引擎更新后若此处又变回
	 * `Browser.window == null`，本仓库 11 个 node 自检会全灭 —— 见
	 * `docs/engine-local-patch-ledger-knowledge.md`（台账 P1）与
	 * `docs/engine-update-compat-knowledge.md §4.1`；体检：`node tools/engine-patch-check/check.mjs`。
	 */
	private static function __hasWindow():Bool {
		return js.Syntax.code("typeof window != 'undefined' && window != null");
	}

	public static function init():Void {
		if (__initialized || !__hasWindow() || !Reflect.isFunction(Reflect.field(Browser.window, "addEventListener")))
			return;
		__initialized = true;
		// 捕获阶段先接管，避免隐藏输入框与 OpenFL 后端重复处理同一次 Tab。
		Browser.window.addEventListener("keydown", onKeyDown, true);
	}

	/** 页面中的其他原生编辑控件不使用引擎的 Tab 导航。 */
	public static function isExternalEditorFocused():Bool {
		// [ABN-PATCH 2026-10-25 / 2026-11-10 重放] 同 `init()`：node 宿主没有 window/document
		if (!__hasWindow() || Browser.document == null)
			return false;
		var active = Browser.document.activeElement;
		return active != null && active != HTML5TextInputUtils.textureArea
			&& (active.tagName == "INPUT" || active.tagName == "TEXTAREA" || Reflect.field(active, "isContentEditable") == true);
	}

	/** 无当前焦点时，使用最上层开启了回退的舞台。 */
	private static function __fallbackStage():Stage {
		var stages = Hxmaker.engine == null ? null : Hxmaker.engine.stages;
		if (stages == null)
			return Hxmaker.topView.tabFocusFallback ? Hxmaker.topView : null;
		var index = stages.length;
		while (index-- > 0) {
			var stage = stages[index];
			if (stage != null && stage.tabFocusFallback)
				return stage;
		}
		return null;
	}

	private static function onKeyDown(event:js.html.KeyboardEvent):Void {
		if (event.key != "Tab" && event.keyCode != Keyboard.TAB)
			return;
		// 带修饰键的组合交给页面和业务快捷键，避免吞掉 Ctrl+Tab 等操作。
		if (event.ctrlKey || event.altKey || event.metaKey)
			return;
		// 页面中其他原生编辑控件已有焦点时，保留它们自己的 Tab 行为。
		if (isExternalEditorFocused())
			return;
		var current = @:privateAccess Stage.__focus;
		var stage:Stage = current != null && current.stage != null ? current.stage : __fallbackStage();
		if (stage == null || stage.isDisposed)
			return;
		if (!(current != null && !current.isDisposed && current is ITabFocusable) && !stage.tabFocusFallback)
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
		stage.handleKeyboardEvent(engineEvent);
		if (engineEvent.isDefaultPrevented)
			event.preventDefault();
		// 与后端原有顺序一致：事件分发结束后更新按键状态。
		@:privateAccess KeyboardTools.onKeyDown(Keyboard.TAB);
	}
}
#end
