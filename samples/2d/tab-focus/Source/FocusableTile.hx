package;

import hx.display.Box;
import hx.display.ITabFocusable;
import hx.display.Label;
import hx.display.Quad;
import hx.display.TextFormat;
import hx.events.Event;
import hx.events.MouseEvent;

/** 普通显示对象通过实现接口加入 Tab 顺序，无需向舞台额外注册。 */
class FocusableTile extends Box implements ITabFocusable {
	public var tabEnabled:Bool = true;
	public var tabIndex:Int = 4;
	private var __surface:Quad;

	public function new() {
		super();
		name = "自定义组件";
		width = 400;
		height = 38;
		mouseClickEnabled = true;
		mouseChildren = false;
		__surface = new Quad(400, 38, 0x34435a);
		background = __surface;
		var label = new Label("自定义组件：实现 ITabFocusable", new TextFormat(null, 16, 0xffffff));
		label.x = 12;
		label.width = 376;
		label.height = 38;
		label.wordWrap = false;
		label.verticalAlign = MIDDLE;
		addChild(label);
		addEventListener(MouseEvent.MOUSE_DOWN, _ -> focus());
		addEventListener(Event.FOCUS_OVER, (event:Event) -> {
			if (event.target == this)
				__surface.data = 0x256fbc;
		});
		addEventListener(Event.FOCUS_OUT, (event:Event) -> {
			if (event.target == this)
				__surface.data = 0x34435a;
		});
	}

	public function focus():Void {
		// 支持鼠标及业务调用；通过 Tab 切入时舞台已设置焦点。
		if (stage != null)
			stage.focus = this;
	}
}
