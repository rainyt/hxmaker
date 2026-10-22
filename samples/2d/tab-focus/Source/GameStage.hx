package;

import hx.display.Box;
import hx.display.DisplayObject;
import hx.display.InputLabel;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Stage;
import hx.display.TextFormat;
import hx.events.Event;
import hx.events.MouseEvent;

/** 展示输入框切换、接口扩展，以及必须已有有效焦点的起点约束。 */
class GameStage extends Stage {
	private var __status:Label;

	override public function onStageInit():Void {
		super.onStageInit();
		addText("Tab 焦点切换", 24, 20, 752, 36, 26, 0xffffff);
		addText("先点击一个输入框，再用 Tab / Shift+Tab 切换。", 24, 66, 752, 24);
		addText("顺序：用户名 → 邮箱 → 密码 → 自定义组件 → 用户名", 24, 94, 752, 24, 15, 0x93b3dc);
		__status = addText("当前焦点：无。直接按 Tab 不会自动选中输入框。", 24, 132, 752, 28, 16, 0x71d9bb);

		var username = addInput("用户名", "请输入用户名", 180, 1);
		var email = addInput("邮箱", "请输入邮箱", 234, 2);
		var password = addInput("密码", "请输入密码", 288, 3);
		password.displayAsPassword = true;
		var excluded = addInput("备注（跳过）", "可点击编辑，Tab 切换已关闭", 342, 0);
		excluded.tabEnabled = false;
		addText("tabEnabled = false", 600, 342, 180, 38, 14, 0xe4b878);

		addText("自定义组件", 24, 396, 148, 38);
		var tile = new FocusableTile();
		tile.x = 180;
		tile.y = 396;
		addChild(tile);
		watchFocus(tile);
		addText("tabIndex = 4", 600, 396, 180, 38, 14, 0x93b3dc);

		addAction("聚焦第一个输入框", 24, () -> username.focus());
		addAction("清空焦点", 228, () -> {
			focus = null;
			__status.data = "当前焦点：无。直接按 Tab 不会自动选中输入框。";
		});
		addAction("切换邮箱是否参与", 432, () -> {
			email.tabEnabled = !email.tabEnabled;
			focus = null;
			__status.data = "邮箱 Tab 切换已" + (email.tabEnabled ? "开启" : "关闭") + "；请重新点击输入框开始。";
		});
		addText("蓝色表示当前焦点。备注可点击输入，但不参与 Tab，也不能作为切换起点。", 24, 526, 752, 24, 14);
		addText("点击“清空焦点”后按 Tab，可观察无焦点时不会启动切换。", 24, 552, 752, 24, 14);
		// 不主动调用 focus()，保留初始无焦点状态供交互观察。
	}

	private function addInput(title:String, placeholder:String, y:Float, index:Int):InputLabel {
		addText(title, 24, y, 148, 38);
		var input = new InputLabel();
		input.name = title;
		input.x = 180;
		input.y = y;
		input.width = 400;
		input.height = 38;
		input.wordWrap = false;
		input.verticalAlign = MIDDLE;
		input.textFormat = new TextFormat(null, 18, 0xffffff);
		input.placeholderTextFormat = new TextFormat(null, 16, 0x93a3b8);
		input.placeholder = placeholder;
		input.tabIndex = index;
		var surface = new Quad(400, 38, 0x283548);
		input.background = surface;
		input.addEventListener(Event.FOCUS_OVER, (event:Event) -> {
			if (event.target == input)
				surface.data = 0x256fbc;
		});
		input.addEventListener(Event.FOCUS_OUT, (event:Event) -> {
			if (event.target == input)
				surface.data = 0x283548;
		});
		addChild(input);
		watchFocus(input);
		if (index > 0)
			addText("tabIndex = " + index, 600, y, 180, 38, 14, 0x93b3dc);
		return input;
	}

	private function watchFocus(object:DisplayObject):Void {
		object.addEventListener(Event.FOCUS_OVER, (event:Event) -> {
			if (event.target != object)
				return;
			var input = Std.downcast(object, InputLabel);
			__status.data = "当前焦点：" + object.name
				+ (input != null && !input.tabEnabled ? "。该对象不启动 Tab 焦点查询。" : "。可按 Tab / Shift+Tab 切换。");
		});
	}

	private function addText(text:String, x:Float, y:Float, width:Float, height:Float, size:Int = 16, color:UInt = 0xbcc9db):Label {
		var label = new Label(text, new TextFormat(null, size, color));
		label.x = x;
		label.y = y;
		label.width = width;
		label.height = height;
		label.wordWrap = false;
		label.verticalAlign = MIDDLE;
		label.mouseEnabled = false;
		addChild(label);
		return label;
	}

	private function addAction(text:String, x:Float, action:Void->Void):Void {
		var button = new Box();
		button.x = x;
		button.y = 468;
		button.width = 188;
		button.height = 36;
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		button.background = new Quad(188, 36, 0x34435a);
		var label = new Label(text, new TextFormat(null, 15, 0xffffff));
		label.width = 188;
		label.height = 36;
		label.wordWrap = false;
		label.horizontalAlign = CENTER;
		label.verticalAlign = MIDDLE;
		button.addChild(label);
		button.addEventListener(MouseEvent.CLICK, (event:MouseEvent) -> {
			event.bubbling = false;
			event.preventDefault();
			action();
		});
		addChild(button);
	}
}
