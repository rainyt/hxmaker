package;

import hx.display.InputLabel;
import hx.display.Label;
import hx.events.Event;
#if wechat
import hx.utils.inputs.WechatTextInputUtils;
#else
import hx.utils.inputs.HTML5TextInputUtils;
#end

/** 验证单行数据约束、原生输入拦截和过滤后的选区映射。 */
@:access(hx.display.InputLabel)
@:access(InputLabelOverflowCheck)
class InputLabelSingleLineCheck {
	static var checks = 0;
	static function assert(value:Bool, message:String):Void {
		checks++;
		if (!value) throw message;
	}
	static function main():Void {
		InputLabelOverflowCheck.configureText();
		checkData();
		#if wechat
		checkWechat();
		#else
		checkHtml5();
		#end
		var result = "单行输入验证通过：" + checks + " 项断言";
		trace(result);
		#if single_line_browser_checks
		js.Browser.document.getElementById("result").textContent = result;
		prepareBrowserInput();
		#end
	}
	static function checkData():Void {
		var input = new InputLabel();
		input.data = "a\r\nbc\n";
		assert(input.data == "a\r\nbc\n", "多行模式保留显式换行");
		input.syncSelectionFromNative(3, 6, 3); input.selectionAnchor = 6;
		input.__dragging = true;
		input.wordWrap = false;
		assert(input.data == "abc" && input.label.data == "abc", "切换到单行清理已有 CR、LF 和 CRLF");
		assert(input.selectionStart == 1 && input.selectionEnd == 3, "切换模式修正选区两端");
		assert(input.__caretIndex == 1 && input.selectionAnchor == 3, "切换模式保留反向活动端和拖拽锚点");
		input.__dragging = false;
		input.data = "\ra\nb\r\nc";
		assert(input.data == "abc", "程序直接赋值也执行单行约束");
		assert(input.getNormalizedInputIndex("A\r\nBC\nD", 4) == 2, "只扣除插入位置之前的换行");
		assert(input.getNormalizedInputIndex("A\r\nBC\nD", 100) == 4, "越界插入位置归一化");
		assert(input.getNormalizedInputIndex(null, 1) == 0, "空文本的位置安全归零");
		input.displayAsPassword = true; input.data = "x\ny\r";
		assert(input.data == "xy" && input.label.data == "**", "密码模式先约束原文再生成掩码");
		input.wordWrap = true; input.data = "x\ny";
		assert(input.data == "x\ny", "重新启用多行可接受换行");
		var label = new Label(); label.wordWrap = false; label.data = "a\nb";
		assert(label.data == "a\nb", "普通 Label 的 wordWrap 语义保持不变");
	}

	#if !wechat
	static function event(key:String = "Enter", code:Int = 13, composing:Bool = false, type:String = ""):Dynamic {
		var event:Dynamic = {key: key, keyCode: code, isComposing: composing, inputType: type, defaultPrevented: false};
		event.preventDefault = () -> event.defaultPrevented = true;
		return event;
	}
	static function checkHtml5():Void {
		var input = new InputLabel(); input.wordWrap = false; input.data = "abcd";
		var area:Dynamic = {value: "abcd", style: {}, selectionStart: 1, selectionEnd: 3, selectionDirection: "forward"};
		area.setSelectionRange = function(start:Int, end:Int, direction:String):Void {
			area.selectionStart = start; area.selectionEnd = end; area.selectionDirection = direction;
		};
		HTML5TextInputUtils.input = input; HTML5TextInputUtils.textureArea = cast area;
		input.syncSelectionFromNative(1, 3);
		var changes = 0;
		input.addEventListener(Event.CHANGE, _ -> changes++);
		var e = event(); HTML5TextInputUtils.onKeyDown(cast e);
		assert(e.defaultPrevented && area.value == "abcd" && area.selectionStart == 1 && area.selectionEnd == 3,
			"有选区时 Enter 在编辑前被拦截且不删除文本");
		e = event(); e.shiftKey = true; HTML5TextInputUtils.onKeyDown(cast e);
		assert(e.defaultPrevented, "Shift+Enter 同样不插入换行");
		e = event("a", 65); HTML5TextInputUtils.onKeyDown(cast e);
		assert(!e.defaultPrevented, "普通字符键放行");
		e = event("Enter", 13, true); HTML5TextInputUtils.onKeyDown(cast e);
		assert(!e.defaultPrevented, "输入法确认候选词的 Enter 放行");
		e = event("Enter", 229); HTML5TextInputUtils.onKeyDown(cast e);
		assert(!e.defaultPrevented, "兼容输入法的 229 键码");
		for (type in ["insertLineBreak", "insertParagraph"]) {
			e = event("", 0, false, type); HTML5TextInputUtils.onBeforeInput(cast e);
			assert(e.defaultPrevented, "beforeinput 阻止 " + type);
		}
		e = event("", 0, false, "insertFromPaste"); HTML5TextInputUtils.onBeforeInput(cast e);
		assert(!e.defaultPrevented, "多行粘贴仍接受其中的有效文字");
		HTML5TextInputUtils.onCompositionStart();
		e = event(); HTML5TextInputUtils.onKeyDown(cast e);
		assert(!e.defaultPrevented, "组合阶段即使缺少 isComposing 标志也不拦截 Enter");
		area.value = "中\n文"; area.setSelectionRange(3, 3, "none");
		HTML5TextInputUtils.onInput(); HTML5TextInputUtils.onKeyUp(); HTML5TextInputUtils.onNativeSelect();
		assert(input.data == "abcd" && area.value == "中\n文" && changes == 0, "组合阶段不重写缓冲、不回读过渡选区");
		HTML5TextInputUtils.onCompositionEnd();
		assert(input.data == "中文" && area.value == "中文" && input.selectionEnd == 2 && area.selectionEnd == 2,
			"组合结束后过滤并修正光标");
		HTML5TextInputUtils.onInput();
		assert(changes == 1, "compositionend 后重复 input 不重复派发 CHANGE");
		area.value = "A\r\nBC\nD"; area.setSelectionRange(4, 7, "backward"); HTML5TextInputUtils.onInput();
		assert(input.data == "ABCD" && area.value == "ABCD", "原生多行粘贴清理并回写文本");
		assert(input.selectionStart == 2 && input.selectionEnd == 4 && input.__caretIndex == 2
			&& area.selectionStart == 2 && area.selectionEnd == 4 && area.selectionDirection == "backward",
			"过滤后保留原生反向选区的端点和方向");
		input.data = "x\ny\rz";
		assert(input.data == "xyz" && area.value == "xyz", "活动输入框直接赋值同步原生文本");
		var before = changes;
		area.value = "xyz\n"; area.setSelectionRange(4, 4, "none"); HTML5TextInputUtils.onInput();
		assert(input.data == "xyz" && area.value == "xyz" && changes == before && input.selectionEnd == 3,
			"只包含无效换行的变更不派发 CHANGE");
		area.value = StringTools.rpad("", "a", 10000) + "\n"; area.setSelectionRange(9000, 10001, "backward");
		HTML5TextInputUtils.onInput();
		assert(input.data.length == 9999 && area.value.length == 9999 && area.selectionStart == 9000 && area.selectionEnd == 9999,
			"长度限制后原生文本和选区仍一致");
		input.wordWrap = true;
		e = event(); HTML5TextInputUtils.onKeyDown(cast e);
		assert(!e.defaultPrevented, "多行模式 Enter 放行");
		e = event("", 0, false, "insertLineBreak"); HTML5TextInputUtils.onBeforeInput(cast e);
		assert(!e.defaultPrevented, "多行模式 beforeinput 换行放行");
		area.value = "a\nb"; area.setSelectionRange(3, 3, "none"); HTML5TextInputUtils.onInput();
		assert(input.data == "a\nb" && input.selectionEnd == 3, "多行输入保留换行和原生光标");
		input.wordWrap = false;
		assert(input.data == "ab" && area.value == "ab" && area.selectionEnd == 2 && input.selectionEnd == 2,
			"活动输入框切换到单行同步清理文本及光标");
		HTML5TextInputUtils.input = null; HTML5TextInputUtils.textureArea = null;
	}
	#end

	#if wechat
	static function checkWechat():Void {
		var shown:Dynamic = null;
		var updated:Array<String> = [];
		var wx:Dynamic = {showKeyboard: options -> shown = options, updateKeyboard: options -> updated.push(options.value),
			hideKeyboard: options -> {}, onKeyboardInput: callback -> {}, onKeyboardConfirm: callback -> {},
			onKeyboardComplete: callback -> {}, offKeyboardInput: callback -> {}, offKeyboardConfirm: callback -> {}, offKeyboardComplete: callback -> {}};
		js.Syntax.code("globalThis.wx = {0}", wx);
		var input = new InputLabel(); input.wordWrap = false; input.data = "a";
		var changes = 0; input.addEventListener(Event.CHANGE, _ -> changes++);
		WechatTextInputUtils.openInput(input);
		assert(shown.multiple == false && shown.defaultValue == "a", "微信键盘按单行模式打开");
		WechatTextInputUtils.onKeyboardInput({value: "a\r\nb\n"});
		assert(input.data == "ab" && WechatTextInputUtils.inputValue == "ab" && updated[updated.length - 1] == "ab",
			"微信回调过滤并同步键盘内容");
		assert(input.selectionEnd == 2 && changes == 1, "微信过滤后光标位于末尾");
		WechatTextInputUtils.onKeyboardConfirm({value: "ab\n"});
		assert(input.data == "ab" && changes == 1, "微信确认中无效换行不重复派发 CHANGE");
		input.wordWrap = true;
		assert(shown.multiple == true, "活动微信键盘切换到多行配置");
		WechatTextInputUtils.onKeyboardInput({value: "a\nb"});
		assert(input.data == "a\nb", "微信多行输入保留换行");
		input.wordWrap = false;
		assert(input.data == "ab" && shown.multiple == false && shown.defaultValue == "ab", "微信切回单行同步配置和文本");
		input.data = "x\ny";
		assert(WechatTextInputUtils.inputValue == "xy" && updated[updated.length - 1] == "xy", "微信活动输入框直接赋值同步原生内容");
		WechatTextInputUtils.closeInput(input);
	}
	#end

	#if single_line_browser_checks
	/** 浏览器提供真实键盘和粘贴操作，结果同步到页面便于验证。 */
	static function prepareBrowserInput():Void {
		var input = new InputLabel(); input.wordWrap = false; input.data = "abcdef";
		input.syncSelectionFromNative(1, 5);
		HTML5TextInputUtils.openInput(input);
		var area = HTML5TextInputUtils.textureArea;
		area.style.position = "static"; area.style.zIndex = "0";
		area.setAttribute("aria-label", "单行原生输入");
		var update = () -> {
			js.Browser.document.getElementById("native-result").textContent = "引擎文本=" + haxe.Json.stringify(input.data)
				+ "；原生文本=" + haxe.Json.stringify(area.value) + "；选区=" + area.selectionStart + "," + area.selectionEnd;
		};
		input.addEventListener(Event.CHANGE, _ -> update());
		area.addEventListener("keyup", _ -> update());
		area.addEventListener("select", _ -> update());
		var mode = js.Browser.document.getElementById("mode");
		mode.addEventListener("click", _ -> {input.wordWrap = !input.wordWrap; mode.textContent = input.wordWrap ? "切换到单行" : "切换到多行"; update();});
		update();
	}
	#end
}
