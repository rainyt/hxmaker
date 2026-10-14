package hx.display;

/** 不执行操作的分隔线，点击不会关闭菜单。 */
class ContextMenuSeparator extends Box {
	public var line(default, null):Quad;
	public function new() {
		super();
		width = 180;
		height = 9;
		line = new Quad(180, 1, 0x454545);
		line.y = 4;
		line.mouseEnabled = false;
		addChild(line);
		mouseChildren = false;
		mouseClickEnabled = true;
	}
	override public function updateLayout():Void {
		super.updateLayout();
		line.width = width;
	}
}
