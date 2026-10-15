package hx.display;

import hx.events.Event;
import hx.events.Keyboard;
import hx.events.KeyboardEvent;
import hx.events.MouseEvent;
import hx.layout.VerticalLayout;

/** 通用右键菜单。条目属于普通显示树，展示时由所属舞台的滚动浮层承载。 */
@:access(hx.display.Stage)
class ContextMenu extends Box {
	public static inline var OPENING:String = "contextMenuOpening";
	public static inline var OPENED:String = "contextMenuOpened";
	public static inline var CLOSED:String = "contextMenuClosed";

	public var isOpen(get, never):Bool;
	public var context(get, never):ContextMenuContext;
	/** 默认布局使用的内边距，可通过替换 layout 完全定制布局。 */
	public var padding:Float = 4;
	private var __context:ContextMenuContext;
	private var __open:Bool = false;
	private var __revision:Int = 0;
	private var __bindings:Array<DisplayObject> = [];
	private var __host:Stage;
	private var __previousFocus:DisplayObject;
	private var __viewport:ContextMenuViewport;
	private var __defaultBackground:Quad;
	private var __measuredWidth:Float = 0;
	private var __measuredHeight:Float = 0;
	private var __owner:DisplayObject;

	override function get_width():Float return (__width != null ? __width : __measuredWidth) * scaleX;
	override function get_height():Float return (__height != null ? __height : __measuredHeight) * scaleY;

	override function __getRect():hx.geom.Rectangle {
		__rect.width = __width != null ? __width : __measuredWidth;
		__rect.height = __height != null ? __height : __measuredHeight;
		return __rect;
	}

	override function __getBounds(parent:hx.geom.Matrix = null):hx.geom.Rectangle {
		var transform = __transform.clone();
		if (parent != null)
			transform.concat(parent);
		return __getLocalBounds(__getRect(), transform);
	}

	override public function updateLayout():Void {
		super.updateLayout();
		__measuredWidth = __measuredHeight = 0;
		for (item in children) {
			if (item.hide)
				continue;
			__measuredWidth = Math.max(__measuredWidth, item.x + item.width);
			__measuredHeight = Math.max(__measuredHeight, item.y + item.height);
		}
		__measuredWidth += padding;
		__measuredHeight += padding;
		__defaultBackground.width = width;
		__defaultBackground.height = height;
	}

	public function new() {
		super();
		layout = new ContextMenuLayout(this);
		mouseClickEnabled = true;
		__defaultBackground = new Quad(0, 0, 0x252526);
		background = __defaultBackground;
	}

	private function get_isOpen():Bool return __open;
	private function get_context():ContextMenuContext return __context;

	public function addItem(item:DisplayObject):DisplayObject {
		if (isDisposed)
			throw "菜单已经销毁";
		if (item.parent != this)
			addChild(item);
		return item;
	}

	public function removeItem(item:DisplayObject):DisplayObject {
		removeChild(item);
		return item;
	}

	/** 只解除显示关系，不销毁条目。 */
	public function clearItems():Void removeChildren();

	@:allow(hx.display.DisplayObject)
	private function bind(owner:DisplayObject):Void {
		if (!isDisposed && __bindings.indexOf(owner) < 0)
			__bindings.push(owner);
	}

	@:allow(hx.display.DisplayObject)
	private function unbind(owner:DisplayObject):Void {
		__bindings.remove(owner);
		if (__context != null && __context.owner == owner)
			close();
	}

	/** 在指定对象所属舞台主动打开菜单，无需绑定右键。坐标使用舞台本地坐标。 */
	public function show(owner:DisplayObject, stageX:Float, stageY:Float, ?target:DisplayObject):Void {
		open(owner, target == null ? owner : target, stageX, stageY, false);
	}

	private function open(owner:DisplayObject, target:DisplayObject, stageX:Float, stageY:Float, requireBinding:Bool = true):Void {
		if (isDisposed || owner == null || owner.isDisposed || owner.stage == null)
			return;
		close();
		if (isDisposed || owner.isDisposed || owner.stage == null)
			return;
		var host = owner.stage;
		if (host.openedContextMenu != null)
			host.openedContextMenu.close();
		// CLOSED 监听可以重新打开其他菜单，此时尊重已建立的新展示。
		if (isDisposed || owner.isDisposed || owner.stage != host || __context != null || host.openedContextMenu != null
			|| (requireBinding && owner.contextMenu != this))
			return;
		var revision = ++__revision;
		__context = {owner: owner, target: target, stageX: stageX, stageY: stageY};
		var opening = new Event(OPENING, true, false, __context);
		try {
			dispatchEvent(opening);
		} catch (error:Dynamic) {
			if (__revision == revision)
				close();
			throw error;
		}
		if (__revision != revision)
			return;
		if (opening.isDefaultPrevented || numChildren == 0 || isDisposed || owner.isDisposed
			|| (requireBinding && owner.contextMenu != this) || owner.stage != host) {
			__context = null;
			return;
		}
		if (host.openedContextMenu != null) {
			__context = null;
			return;
		}
		__host = host;
		__owner = owner;
		owner.addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		__previousFocus = host.focus;
		__viewport = new ContextMenuViewport();
		__viewport.includeInLayout = false;
		x = y = 0;
		__viewport.addChild(this);
		host.addChild(__viewport);
		__open = true;
		host.openedContextMenu = this;
		var events = host.__contextMenuEvents;
		events.addEventListener(MouseEvent.MOUSE_DOWN, onOutsideDown);
		events.addEventListener(MouseEvent.RIGHT_MOUSE_DOWN, onOutsideDown);
		events.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		events.addEventListener(Event.DEACTIVATE, onDeactivate);
		events.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		place();
		dispatchEvent(new Event(OPENED, false, false, __context));
	}

	private function place():Void {
		if (!__open)
			return;
		if (__host.stageWidth <= 0 || __host.stageHeight <= 0) {
			close();
			return;
		}
		updateLayout();
		var contentWidth = Math.max(1, width);
		var contentHeight = Math.max(1, height);
		__defaultBackground.width = contentWidth;
		__defaultBackground.height = contentHeight;
		__viewport.width = Math.min(contentWidth, __host.stageWidth);
		__viewport.height = Math.min(contentHeight, __host.stageHeight);
		__viewport.x = Math.max(0, Math.min(__context.stageX, __host.stageWidth - __viewport.width));
		__viewport.y = Math.max(0, Math.min(__context.stageY, __host.stageHeight - __viewport.height));
		__viewport.scrollX = Math.max(Math.min(0, __viewport.scrollX), -Math.max(0, contentWidth - __viewport.width));
		__viewport.scrollY = Math.max(Math.min(0, __viewport.scrollY), -Math.max(0, contentHeight - __viewport.height));
		__viewport.invalidate();
	}

	/** 判断命中对象是否仍在菜单浮层内部，包括自定义组件的所有子节点。 */
	private function containsTarget(target:DisplayObject):Bool {
		while (target != null) {
			if (target == __viewport)
				return true;
			target = target.parent;
		}
		return false;
	}

	private function onOutsideDown(event:MouseEvent):Void {
		if (!containsTarget(cast event.target))
			close();
	}

	private function onKeyDown(event:KeyboardEvent):Void {
		if (event.keyCode == Keyboard.ESCAPE) {
			close();
			event.preventDefault();
		}
	}

	private function onDeactivate(event:Event):Void close();
	private function onResize(event:Event):Void place();
	private function onRemoved(event:Event):Void close();

	/** 幂等关闭，先清理展示和上下文，再派发携带旧上下文的 CLOSED。 */
	public function close():Void {
		++__revision;
		var wasOpen = __open;
		var context = __context;
		var host = __host;
		var viewport = __viewport;
		var previousFocus = __previousFocus;
		var restoreFocus = host != null && containsTarget(host.focus);
		__open = false;
		__context = null;
		__host = null;
		__previousFocus = null;
		if (__owner != null)
			__owner.removeEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		__owner = null;
		removeEventListener(Event.REMOVED_FROM_STAGE, onRemoved);
		if (host != null) {
			var events = host.__contextMenuEvents;
			events.removeEventListener(MouseEvent.MOUSE_DOWN, onOutsideDown);
			events.removeEventListener(MouseEvent.RIGHT_MOUSE_DOWN, onOutsideDown);
			events.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			events.removeEventListener(Event.DEACTIVATE, onDeactivate);
			events.removeEventListener(Event.RESIZE, onResize);
			if (host.openedContextMenu == this)
				host.openedContextMenu = null;
		}
		__viewport = null;
		if (viewport != null) {
			if (parent != null)
				parent.removeChild(this);
			if (viewport.parent != null)
				viewport.parent.removeChild(viewport);
			viewport.dispose();
		}
		if (restoreFocus)
			host.focus = previousFocus != null && previousFocus.stage != null && !previousFocus.isDisposed ? previousFocus : null;
		if (wasOpen)
			dispatchEvent(new Event(CLOSED, false, false, context));
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		isDisposed = true;
		close();
		for (owner in __bindings.copy())
			owner.contextMenu = null;
		__bindings = [];
		// 遵循容器约定，仍在菜单中的条目会销毁；clearItems 移出的条目由使用者管理。
		super.dispose();
	}
}

/** 默认纵向布局，标准条目填充内容宽度，自定义条目保持自己的尺寸。 */
private class ContextMenuLayout extends VerticalLayout {
	private var contextMenu:ContextMenu;
	public function new(menu:ContextMenu) {
		super();
		this.contextMenu = menu;
		gap = 2;
	}
	override public function update(children:Array<DisplayObject>):Void {
		var width:Float = 0;
		for (item in children) {
			if (item is DisplayObjectContainer)
				cast(item, DisplayObjectContainer).updateLayout();
			width = Math.max(width, item.width);
		}
		var y = contextMenu.padding;
		for (item in children) {
			item.x = contextMenu.padding;
			item.y = y;
			if (item is ContextMenuItem || item is ContextMenuSeparator)
				item.width = width;
			y += item.height + gap;
		}
	}
}

/** 菜单滚动只使用滚轮，避免输入框、滑块的拖动触发整个菜单滚动。 */
private class ContextMenuViewport extends Scroll {
	public function new() super(false);
	override private function onMouseDown(event:MouseEvent):Void {}
	override private function onMouseWheel(event:MouseEvent):Void {
		var horizontal = hx.utils.KeyboardTools.isKeyDown(Keyboard.SHIFT) || contentHeight <= height;
		var distance = event.delta * 12;
		if (horizontal)
			scrollX = Math.max(-Math.max(0, contentWidth - width), Math.min(0, scrollX + distance));
		else
			scrollY = Math.max(-Math.max(0, contentHeight - height), Math.min(0, scrollY + distance));
	}
}
