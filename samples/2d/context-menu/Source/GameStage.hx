package;

import hx.core.Hxmaker;
import hx.display.*;
import hx.events.Event;

/** 使用 haxelib run openfl test project.xml html5 运行；展示固定、自定义及共享动态菜单。 */
class GameStage extends hx.display.Stage {
	override public function onStageInit():Void {
		super.onStageInit();
		var host = this;
		var status = new Label("右键彩色区域、树节点、资源目录或面板空白处", new TextFormat(null, 16, 0xffffff));
		status.x = 20; status.y = 20; host.addChild(status);

		var area = new Quad(220, 64, 0x386a91); area.x = 20; area.y = 60; host.addChild(area);
		var fixedMenu = new ContextMenu();
		fixedMenu.addItem(new ContextMenuItem("显示右键位置", context -> {
			status.data = "右键位置：" + context.stageX + ", " + context.stageY;
		}));
		var disabled = new ContextMenuItem("暂不可用"); disabled.enabled = false; fixedMenu.addItem(disabled);
		fixedMenu.addItem(new ContextMenuSeparator());
		// 自定义条目内部正常输入；框架不会自动关闭，Esc 优先关闭菜单。
		var input = new InputLabel(); input.width = 220; input.height = 32; input.data = "可持续输入的自定义条目";
		fixedMenu.addItem(input);
		var keepOpen = new ContextMenuItem("更新状态并保持菜单", context -> status.data = "菜单仍然打开");
		keepOpen.closeOnSelect = false; fixedMenu.addItem(keepOpen);
		area.contextMenu = fixedMenu;

		var folder = new TreeItem("目录", [new TreeItem("对象甲"), new TreeItem("对象乙")]);
		var tree = new Tree(); tree.x = 20; tree.y = 160; tree.width = 340; tree.height = 300;
		tree.data = [folder, new TreeItem("根对象")]; host.addChild(tree);
		var finder = new FinderView(); finder.x = 410; finder.y = 160; finder.width = 340; finder.height = 300;
		finder.data = [folder, new TreeItem("资源文件")]; host.addChild(finder);
		var dynamicMenu = new ContextMenu();
		dynamicMenu.addEventListener(ContextMenu.OPENING, (event:Event) -> {
			var context:ContextMenuContext = cast event.data;
			var item = context.owner == tree ? tree.getItemByRenderer(context.target) : finder.getItemByRenderer(context.target);
			// 示例独占这些临时条目，重建时主动销毁；clearItems 本身不会销毁对象。
			for (entry in dynamicMenu.children.copy()) entry.dispose();
			dynamicMenu.clearItems();
			if (item == null) {
				dynamicMenu.addItem(new ContextMenuItem("创建条目", _ -> status.data = "右键面板空白区域"));
			} else {
				var data = item;
				dynamicMenu.addItem(new ContextMenuItem("查看：" + data.label, _ -> status.data = "实际右键对象：" + data.label));
			}
		});
		tree.contextMenu = dynamicMenu;
		finder.contextMenu = dynamicMenu;
	}
}
