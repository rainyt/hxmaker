package hx.display;

import hx.events.MouseEvent;

/** 默认文字菜单项，可继承并覆盖 updateStyle 自定义外观。 */
class ContextMenuItem extends Box {
	public var enabled(default, set):Bool = true;
	public var closeOnSelect:Bool = true;
	public var label(default, null):Label;
	public var onSelect:ContextMenuContext->Void;
	public var normalColor:Int = 0x252526;
	public var hoverColor:Int = 0x094771;
	public var textColor:Int = 0xeeeeee;
	public var disabledTextColor:Int = 0x777777;
	private var __hover:Bool = false;
	private var __itemBackground:Quad;

	public function new(text:String, ?onSelect:ContextMenuContext->Void) {
		super();
		this.onSelect = onSelect;
		label = new Label(text, new TextFormat(null, 14, textColor));
		label.mouseEnabled = false;
		label.x = 8;
		label.y = 6;
		addChild(label);
		__itemBackground = new Quad(180, 28, normalColor);
		background = __itemBackground;
		width = Math.max(180, label.width + 16);
		height = 28;
		mouseChildren = false;
		mouseClickEnabled = true;
		addEventListener(MouseEvent.MOUSE_OVER, onOver);
		addEventListener(MouseEvent.MOUSE_OUT, onOut);
		addEventListener(MouseEvent.CLICK, onClick);
	}

	private function set_enabled(value:Bool):Bool {
		enabled = value;
		updateStyle();
		return value;
	}

	public function updateStyle():Void {
		if (__itemBackground != null)
			__itemBackground.data = enabled && __hover ? hoverColor : normalColor;
		if (label != null)
			label.color = enabled ? textColor : disabledTextColor;
	}

	private function onOver(event:MouseEvent):Void {
		__hover = true;
		updateStyle();
	}
	private function onOut(event:MouseEvent):Void {
		__hover = false;
		updateStyle();
	}

	private function onClick(event:MouseEvent):Void {
		if (!enabled)
			return;
		var current:DisplayObject = parent;
		while (current != null && !(current is ContextMenu))
			current = current.parent;
		var menu:ContextMenu = cast current;
		if (menu == null || !menu.isOpen)
			return;
		var context = menu.context;
		// 回调拿到独立快照；回调内重新打开菜单时，旧操作不能关闭新的展示。
		var snapshot:ContextMenuContext = {
			owner: context.owner, target: context.target, stageX: context.stageX, stageY: context.stageY
		};
		try {
			if (onSelect != null)
				onSelect(snapshot);
		} catch (error:Dynamic) {
			if (closeOnSelect && menu.context == context)
				menu.close();
			throw error;
		}
		if (closeOnSelect && menu.context == context)
			menu.close();
	}

	override public function updateLayout():Void {
		super.updateLayout();
		__itemBackground.width = width;
		__itemBackground.height = height;
	}

	override public function dispose():Void {
		onSelect = null;
		super.dispose();
	}
}
