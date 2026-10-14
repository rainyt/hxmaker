package;

import hx.display.*;
import hx.events.*;

/** 使用真实命中、事件分发和显示树验证菜单交互；不启动 GPU 渲染。 */
@:access(hx.display.Stage)
@:access(hx.display.DisplayObject)
@:access(hx.display.EventDispatcher)
@:access(hx.core.Engine)
class ContextMenuCheck {
	static var checks:Int = 0;
	static function assert(value:Bool, message:String):Void {
		checks++;
		if (!value) throw message;
	}
	static function stage():Stage {
		var stage = new Stage();
		stage.__stageWidth = 500;
		stage.__stageHeight = 400;
		return stage;
	}
	static function mouse(stage:Stage, type:String, x:Float, y:Float):MouseEvent {
		stage.__updateTransform(null);
		var event = new MouseEvent(type);
		event.stageX = x;
		event.stageY = y;
		stage.handleMouseEvent(event, true);
		return event;
	}
	static function right(stage:Stage, x:Float, y:Float):MouseEvent {
		mouse(stage, MouseEvent.RIGHT_MOUSE_DOWN, x, y);
		mouse(stage, MouseEvent.RIGHT_MOUSE_UP, x, y);
		return mouse(stage, MouseEvent.RIGHT_CLICK, x, y);
	}
	static function count(stage:Stage):Int {
		var total = 0;
		for (listeners in stage.__contextMenuEvents.__listeners)
			total += listeners.length;
		return total;
	}
	static function menu():ContextMenu {
		var menu = new ContextMenu();
		menu.addItem(new Quad(120, 24, 0xffffff));
		return menu;
	}
	static function main():Void {
		// 行为检查固定文字测量，避免把 GPU 和字体图集初始化混入事件验证。
		untyped hx.render.TextFieldRender.prepareLabel = function(label:Label):Void {
			label.__width = label.data.length * 8;
			label.__height = 20;
			label.__dirty = false;
		};
		var host = stage();
		var owner = new Quad(100, 100, 0xff0000);
		host.addChild(owner);
		assert(!owner.hasEventListener(MouseEvent.RIGHT_CLICK), "未绑定对象没有菜单监听");
		var shared = menu();
		var order:Array<String> = [];
		shared.addEventListener(ContextMenu.OPENING, e -> {
			assert(shared.context == e.data, "OPENING 前上下文可读取");
			order.push("opening");
		});
		shared.addEventListener(ContextMenu.OPENED, e -> order.push("opened"));
		shared.addEventListener(ContextMenu.CLOSED, e -> {
			assert(shared.context == null && e.data != null, "CLOSED 携带旧上下文并清空属性");
			order.push("closed");
		});
		owner.contextMenu = shared;
		owner.contextMenu = shared;
		assert(owner.__listeners.get(MouseEvent.RIGHT_CLICK).length == 1, "重复绑定不增加监听");
		var event = right(host, 10, 10);
		assert(shared.isOpen && event.contextMenuHandled, "普通对象打开菜单并接管原生菜单");
		assert(shared.context.owner == owner && shared.context.target == owner, "上下文的 owner 和 target");
		assert(shared.context.stageX == 10 && shared.context.stageY == 10, "上下文坐标");
		var context = shared.context;
		owner.contextMenu = shared;
		assert(shared.context == context, "重复赋值不改变展示上下文");
		assert(count(host) == 5, "打开期间注册临时监听");
		shared.close(); shared.close();
		assert(order.join(",") == "opening,opened,closed", "生命周期顺序和幂等关闭");
		assert(count(host) == 0, "关闭移除全部舞台临时监听");

		var second = new Quad(100, 100, 0x00ff00); second.x = 150; host.addChild(second);
		second.contextMenu = shared;
		right(host, 160, 10);
		owner.contextMenu = null;
		assert(shared.isOpen && shared.context.owner == second, "解绑共享菜单的其他对象不关闭展示");
		assert(!owner.hasEventListener(MouseEvent.RIGHT_CLICK), "解绑移除菜单监听");
		owner.contextMenu = shared;
		right(host, 10, 10);
		assert(shared.context.owner == owner, "共享菜单切换 owner");
		owner.contextMenu = menu();
		assert(!shared.isOpen, "替换绑定关闭旧菜单");
		owner.contextMenu = shared;
		shared.close();

		var parent = new Box(); parent.x = 300; host.addChild(parent);
		var child = new Quad(80, 80, 0xffffff); parent.addChild(child);
		parent.contextMenu = menu(); child.contextMenu = new ContextMenu();
		event = right(host, 310, 10);
		assert(!parent.contextMenu.isOpen && !child.contextMenu.isOpen && event.contextMenuHandled, "子菜单为空也不回退父菜单");
		child.contextMenu.addEventListener(ContextMenu.OPENING, e -> { child.contextMenu.addItem(new Quad(80, 24)); e.preventDefault(); });
		right(host, 310, 10);
		assert(!parent.contextMenu.isOpen && !child.contextMenu.isOpen && child.contextMenu.context == null, "取消打开不回退且清空上下文");
		child.contextMenu = menu();
		right(host, 310, 10);
		assert(child.contextMenu.isOpen && !parent.contextMenu.isOpen, "最近绑定优先");
		child.contextMenu.close();
		child.mouseEnabled = false;
		right(host, 310, 10);
		assert(!child.contextMenu.isOpen, "绑定不改变禁用鼠标的命中条件");
		child.mouseEnabled = true;

		right(host, 10, 10);
		var viewport = shared.parent.parent;
		assert(viewport.parent == host && cast(shared.parent, DisplayObject) != owner, "浮层属于实际舞台");
		mouse(host, MouseEvent.MOUSE_DOWN, 15, 15);
		assert(shared.isOpen, "内部组件点击不误判为外部");
		var escape = new KeyboardEvent(KeyboardEvent.KEY_DOWN); escape.keyCode = Keyboard.ESCAPE;
		host.handleKeyboardEvent(escape);
		assert(!shared.isOpen && escape.isDefaultPrevented && count(host) == 0, "Esc 优先关闭并移除监听");
		right(host, 10, 10); mouse(host, MouseEvent.MOUSE_DOWN, 480, 350);
		assert(!shared.isOpen, "外部左键关闭");
		right(host, 10, 10); mouse(host, MouseEvent.RIGHT_MOUSE_DOWN, 480, 350);
		assert(!shared.isOpen, "外部右键关闭");
		right(host, 10, 10); host.dispatchEvent(new Event(Event.DEACTIVATE));
		assert(!shared.isOpen, "舞台失活关闭");
		right(host, 10, 10); host.removeChild(owner);
		assert(!shared.isOpen && owner.contextMenu == shared, "移出舞台关闭但保留绑定");
		host.addChild(owner);
		right(host, 10, 10);
		assert(shared.isOpen, "重加舞台仍可打开");
		shared.close();

		var huge = new ContextMenu(); huge.addItem(new Quad(800, 800)); second.contextMenu = huge;
		right(host, 240, 90);
		var scroll:Scroll = cast huge.parent.parent;
		assert(scroll.width == 500 && scroll.height == 400 && scroll.x == 0 && scroll.y == 0, "超长菜单限制尺寸并避让");
		mouse(host, MouseEvent.MOUSE_WHEEL, 250, 100).delta = -20;
		var wheel = new MouseEvent(MouseEvent.MOUSE_WHEEL); wheel.delta = -20; wheel.target = huge;
		scroll.dispatchEvent(wheel);
		assert(scroll.scrollY < 0, "超长内容能够滚动");
		host.__stageWidth = 450; host.dispatchEvent(new Event(Event.RESIZE));
		assert(scroll.width == 450, "尺寸变化重新限制尺寸");
		huge.close();

		var selectedContext:ContextMenuContext = null;
		var standard = new ContextMenu();
		var item = new ContextMenuItem("执行", c -> selectedContext = c);
		standard.addItem(item); standard.addItem(item);
		assert(standard.numChildren == 1, "重复添加不重复条目");
		second.contextMenu = standard;
		right(host, 160, 10);
		item.enabled = false;
		item.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		assert(selectedContext == null && standard.isOpen, "禁用项不执行也不关闭");
		item.enabled = true; item.closeOnSelect = false;
		context = standard.context;
		item.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		assert(selectedContext != context && selectedContext.owner == second && standard.isOpen, "回调获得独立快照且可保持打开");
		item.closeOnSelect = true; item.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		assert(!standard.isOpen, "默认执行后关闭");
		standard.clearItems();
		assert(item.parent == null && item.hasEventListener(MouseEvent.CLICK), "clearItems 不销毁条目");
		standard.addItem(item);
		right(host, 160, 10);
		item.onSelect = c -> { standard.close(); right(host, 10, 10); };
		item.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		assert(shared.isOpen, "旧回调不关闭后来打开的菜单");
		shared.close();

		var otherHost = stage(); var otherOwner = new Quad(100, 100); otherHost.addChild(otherOwner); otherOwner.contextMenu = menu();
		right(host, 10, 10); right(otherHost, 10, 10);
		assert(shared.isOpen && otherOwner.contextMenu.isOpen, "多舞台菜单分别展示");
		owner.dispose();
		assert(!shared.isOpen && owner.contextMenu == null && otherOwner.contextMenu.isOpen, "owner 销毁解除绑定，不干扰其他舞台");
		second.contextMenu = shared; shared.dispose();
		assert(second.contextMenu == null && shared.isDisposed, "菜单销毁解除全部绑定");
		owner.contextMenu = shared;
		assert(owner.contextMenu == null, "销毁的菜单不能再次绑定");
		otherOwner.contextMenu.close();
		checkControls();
		checkFocusAndItems();
		checkBackend();
		checkPlacement();
		checkStageBinding();
		trace("右键菜单行为验证通过：" + checks + " 项断言");
	}

	static function checkControls():Void {
		var host = stage();
		var tree = new Tree(); tree.width = 200; tree.height = 150; tree.layout = new hx.layout.VerticalLayout(); host.addChild(tree);
		var folder = new TreeItem("目录", [new TreeItem("子项")]); tree.data = [folder]; tree.onUpdate(0);
		var dynamicMenu = menu(); tree.contextMenu = dynamicMenu;
		var selectedBeforeOpening = false;
		dynamicMenu.addEventListener(ContextMenu.OPENING, e -> selectedBeforeOpening = tree.selectedItem == folder);
		right(host, 2, 10);
		assert(!folder.expanded && selectedBeforeOpening, "Tree 箭头右键不展开，选择先于菜单生成");
		assert(tree.getItemByRenderer(dynamicMenu.context.target) == folder, "Tree 从原始命中对象解析节点");
		dynamicMenu.close(); tree.rightClickSelectEnabled = false; tree.selectedItem = null;
		right(host, 2, 10);
		assert(dynamicMenu.isOpen && tree.selectedItem == null, "禁止右键选择仍能打开菜单");
		dynamicMenu.close();
		right(host, 10, 100);
		assert(dynamicMenu.isOpen && tree.getItemByRenderer(dynamicMenu.context.target) == null, "Tree 空白区域不会使用旧选中项");
		dynamicMenu.close();
		tree.rightClickSelectEnabled = true;
		var another = new TreeItem("另一个节点"); tree.data = [folder, another]; tree.onUpdate(0);
		tree.selectedItem = folder; tree.selectedItems.push(another);
		right(host, 30, tree.rowHeight + 5);
		assert(tree.selectedItems.length == 2 && tree.getItemByRenderer(dynamicMenu.context.target) == another, "右键已选中项保持多选并保留实际命中数据");
		dynamicMenu.close();
		var stale = tree.getChildAt(0); tree.refresh();
		assert(tree.getItemByRenderer(stale) == null, "刷新未重绘的 Tree 渲染器不解析旧数据");
		host.removeChild(tree);

		var list = new ListView(); host.addChild(list); list.data = new ArrayCollection(["甲", "乙"]); list.onUpdate(0);
		var renderer = list.getChildAt(0);
		assert(list.getItemByRenderer(renderer) == "甲" && list.getItemByRenderer(list) == null, "ListView 命中查询和空白查询");
		list.data = new ArrayCollection(["新数据"]);
		assert(list.getItemByRenderer(renderer) == null, "ListView 更新数据后不返回旧渲染器数据");
		list.layout = new hx.layout.VirtualVerticalLayout(24);
		list.data = new ArrayCollection([for (i in 0...100) i]); list.onUpdate(0);
		var virtualRenderer = list.getChildAt(0);
		assert(list.getItemByRenderer(virtualRenderer) == 0, "虚拟列表查询初始命中数据");
		list.scrollY = -240; list.onUpdate(0);
		var index = list.getItemIndexByRenderer(virtualRenderer);
		assert(index < 0 || list.getItemByRenderer(virtualRenderer) == index && index > 0, "虚拟列表回收复用后只解析当前数据");
		host.removeChild(list);
		var finder = new FinderView(); host.addChild(finder);
		finder.data = [folder]; finder.onUpdate(0); finder.contextMenu = menu();
		var directory = finder.currentItem;
		right(host, 30, 10);
		assert(finder.contextMenu.isOpen && finder.currentItem == directory, "FinderView 文件夹右键不导航");
		finder.contextMenu.close();
	}
	static function checkFocusAndItems():Void {
		var host = stage();
		var owner = new Quad(100, 100); host.addChild(owner);
		var original = new Quad(50, 50); original.x = 300; host.addChild(original); host.focus = original;
		var menu = new ContextMenu(); var item = new ContextMenuItem("保持打开"); item.closeOnSelect = false;
		menu.addItem(item); var separator = new ContextMenuSeparator(); menu.addItem(separator); owner.contextMenu = menu;
		right(host, 10, 10);
		item.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OVER));
		assert(cast(item.background, Quad).data == item.hoverColor, "标准项悬停高亮");
		item.enabled = false;
		assert(item.label.color == item.disabledTextColor, "禁用样式");
		separator.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		assert(menu.isOpen, "分隔线点击不关闭");
		host.focus = item; menu.close();
		assert(host.focus == original, "关闭恢复有效原焦点");
		right(host, 10, 10); host.focus = item; original.dispose(); menu.close();
		assert(host.focus == null, "销毁的原焦点不能恢复");
		var otherHost = stage(); var otherFocus = new Quad(10,10); otherHost.addChild(otherFocus); otherHost.focus = otherFocus;
		right(host, 10, 10); host.focus = item; menu.close();
		assert(otherHost.focus == otherFocus && host.focus == otherFocus, "保留静态共享焦点并恢复其他舞台有效焦点");
		right(host, 10, 10); otherHost.focus = otherFocus; menu.close();
		assert(otherHost.focus == otherFocus, "关闭不覆盖菜单外新焦点");
		var replacement = new ContextMenu(); replacement.addItem(new Quad(30,20));
		menu.addEventListener(ContextMenu.CLOSED, e -> owner.contextMenu = replacement);
		right(host, 10, 10); owner.contextMenu = null;
		assert(owner.contextMenu == replacement && owner.__listeners.get(MouseEvent.RIGHT_CLICK).length == 1, "关闭监听重新绑定不累积监听");
		host.dispose(); otherHost.dispose();
	}

	static function checkBackend():Void {
		// 仅模拟原生事件表面及窗口尺寸，执行真实后端协调逻辑，不初始化 GPU。
		var host = stage(); var owner = new Quad(100,100); host.addChild(owner); owner.contextMenu = menu();
		host.__updateTransform(null);
		var engine = new hx.core.Engine();
		var renderer:hx.core.Render = Type.createEmptyInstance(hx.core.Render);
		@:privateAccess renderer.__stage = new openfl.display.Sprite(); renderer.stage.scaleX = renderer.stage.scaleY = 2;
		engine.renderer = renderer; engine.stages = [host];
		untyped engine.stage = {window: {__width: 800, __height: 600, __scale: 2}};
		var surface:Dynamic = {getBoundingClientRect: () -> ({left:100, top:100, width:400, height:300})};
		engine.__contextMenuElement = cast {contains: _ -> true, querySelector: _ -> surface};
		var prevented = false;
		var event:Dynamic = {target:{}, clientX:115, clientY:115, cancelable:true, preventDefault: () -> prevented = true};
		engine.__onNativeContextMenu(cast event);
		assert(prevented && !owner.contextMenu.isOpen, "原生事件先到达时按缩放坐标屏蔽，且不重复派发右键");
		right(host, 10,10);
		assert(host.hasContextMenuAt(20,20), "已打开菜单内部屏蔽原生菜单");
		assert(mouse(host, MouseEvent.RIGHT_CLICK, 20,20).contextMenuHandled && owner.contextMenu.isOpen, "内部右键接管且保持当前展示");
		owner.contextMenu.close();
		owner.contextMenu = null; prevented = false; engine.__onNativeContextMenu(cast event);
		assert(!prevented, "未绑定区域保留浏览器默认行为");
		owner.contextMenu = menu();
		var blocker = new Quad(100,100); host.addChild(blocker); prevented = false; engine.__onNativeContextMenu(cast event);
		assert(!prevented, "前方未绑定对象不穿透到被遮挡的绑定");
		host.removeChild(blocker);
		engine.__rightMenuHandled = true; engine.__rightMenuTime = haxe.Timer.stamp();
		engine.__rightMenuX = engine.__rightMenuY = 30;
		owner.contextMenu = null; prevented = false; engine.__onNativeContextMenu(cast event);
		assert(prevented, "右键先处理后解绑仍屏蔽同次原生菜单");
		event.clientX = 250; event.clientY = 250; prevented = false; engine.__onNativeContextMenu(cast event);
		assert(!prevented, "同次输入记录不屏蔽其他区域");
		host.dispose();
	}

	static function checkPlacement():Void {
		var host = stage(); var owner = new Quad(500,400); host.addChild(owner); owner.contextMenu = menu();
		host.layout = new hx.layout.VerticalLayout();
		for (position in [{x:1.,y:1.},{x:499.,y:1.},{x:1.,y:399.},{x:499.,y:399.}]) {
			right(host, position.x, position.y);
			var viewport = owner.contextMenu.parent.parent;
			assert(viewport.x >= 0 && viewport.y >= 0 && viewport.x + viewport.width <= 500 && viewport.y + viewport.height <= 400, "舞台四角边界避让");
			host.updateLayout();
			assert(viewport.y < 400 && viewport.visible, "舞台布局不移动或隐藏菜单浮层");
			owner.contextMenu.close();
		}
		host.dispose();
	}

	static function checkStageBinding():Void {
		var host = stage();
		var target = new Quad(100,100); host.addChild(target);
		var binding = menu(); host.contextMenu = binding;
		right(host, 10,10);
		assert(binding.isOpen && host.openedContextMenu == binding && binding.context.owner == host, "舞台绑定属性和打开状态分别保存");
		binding.close();
		assert(host.contextMenu == binding && host.openedContextMenu == null, "关闭菜单不会解除舞台自身绑定");
		right(host, 10,10); host.contextMenu = null;
		assert(!binding.isOpen && host.openedContextMenu == null && !host.hasEventListener(MouseEvent.RIGHT_CLICK), "解除舞台绑定关闭展示并清理监听");
		host.dispose();
	}

}
