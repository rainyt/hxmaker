package;

import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.*;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.ui.UIAssets;

/** 展示 XML 构建、宽度折叠、禁用以及通用业务数据与 FinderView 的组合。 */
class Main extends openfl.display.Sprite {
	static function main():Void openfl.Lib.current.addChild(new Main());

	public function new() {
		super();
		Hxmaker.init(Engine, 800, 600);
		var host = Hxmaker.topView;
		var ids:Map<String, Dynamic> = [];
		var xml = Xml.parse(openfl.Assets.getText("assets/views/BreadcrumbDemo.xml"));
		new UIAssets("").buildItem(xml.firstElement(), host, ids);
		var demo:Box = ids.get("demo");
		var status:Label = ids.get("status");
		var general:BreadcrumbBar = ids.get("generalBar");
		var finderBar:BreadcrumbBar = ids.get("finderBar");
		var finder:FinderView = ids.get("finder");

		var fullPath:Array<BreadcrumbItem> = [
			{label: "演示项目", data: {id: 0}},
			{label: "Assets", data: {id: 1}},
			{label: "Textures", data: {id: 2}},
			{label: "同名目录", data: {id: 3}},
			{label: "同名目录", data: {id: 4}},
			{label: "中文 English 混合名称", data: {id: 5}},
			{label: "UI", data: {id: 6}},
			{label: "很长的当前位置名称，悬停可查看完整文字", data: {id: 7}}
		];
		general.items = fullPath;
		general.addEventListener(BreadcrumbBar.NAVIGATE, (event:Event) -> {
			var navigation:BreadcrumbNavigateEventData = cast event.data;
			status.data = "通用导航请求：索引 " + navigation.index + "，业务 ID " + navigation.item.data.id;
			// 示例的业务层接受请求后更新路径，组件本身不截断数据。
			general.items = general.items.slice(0, navigation.index + 1);
		});
		addAction(demo, "极窄 32", 20, 90, () -> general.width = 32);
		addAction(demo, "窄栏 120", 150, 90, () -> general.width = 120);
		addAction(demo, "中栏 320", 280, 90, () -> general.width = 320);
		addAction(demo, "恢复宽度", 410, 90, () -> general.width = Math.max(0, host.stageWidth - 40));
		addAction(demo, "禁用 / 启用", 20, 130, () -> general.disabled = !general.disabled);
		addAction(demo, "清空路径", 150, 130, () -> general.items = null);
		addAction(demo, "恢复路径", 280, 130, () -> general.items = fullPath);
		host.addEventListener(Event.RESIZE, _ -> general.width = Math.max(0, host.stageWidth - 40));

		var ui = new TreeItem("UI", [new TreeItem("button.png"), new TreeItem("panel.png")]);
		var textures = new TreeItem("Textures", [ui, new TreeItem("地图", [new TreeItem("tiles.png")])]);
		finder.data = [new TreeItem("Assets", [textures, new TreeItem("音效", [new TreeItem("click.wav")])])];
		var syncPath = () -> {
			var items:Array<BreadcrumbItem> = [{label: "演示项目", data: null}];
			for (item in finder.path)
				items.push({label: item.label, data: item});
			finderBar.items = items;
		};
		finderBar.addEventListener(BreadcrumbBar.NAVIGATE, (event:Event) -> {
			var navigation:BreadcrumbNavigateEventData = cast event.data;
			if (navigation.index == 0)
				finder.goToRoot();
			else
				finder.goInto(cast navigation.item.data);
		});
		finder.addEventListener(FinderView.PATH_CHANGED, _ -> syncPath());
		finder.goInto(ui);
		// 数据源替换或项目切换后应主动同步，不能只依赖目录切换事件。
		syncPath();
	}

	private function addAction(parent:Box, text:String, x:Float, y:Float, action:Void->Void):Void {
		var button = new Box();
		button.x = x;
		button.y = y;
		button.width = 116;
		button.height = 28;
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		button.background = new Quad(116, 28, 0x3c3c3c);
		var label = new Label(text, new TextFormat(null, 14, 0xffffff));
		label.x = 8;
		label.width = 100;
		label.height = 28;
		label.wordWrap = false;
		label.verticalAlign = MIDDLE;
		button.addChild(label);
		button.addEventListener(MouseEvent.CLICK, (event:MouseEvent) -> {
			event.bubbling = false;
			event.preventDefault();
			action();
		});
		parent.addChild(button);
	}
}
