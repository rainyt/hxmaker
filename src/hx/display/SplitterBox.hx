package hx.display;

/**
 * 分割容器
 * 内部使用`hx.layout.SplitterLayout`排布子项，子项中可以混排`Splitter`分割条与面板，
 * 面板通过`hx.layout.SplitterLayoutData`声明尺寸规则，未声明的面板均分剩余空间，
 * 拖动分割条可调整相邻面板尺寸，实现类似VSCode的拖拽分栏效果
 */
@:keep
class SplitterBox extends Box {
	override function onInit() {
		super.onInit();
		this.layout = new hx.layout.SplitterLayout();
	}

	/**
	 * 面板排列方向
	 * `HORIZONTAL`为水平排列（竖直分割条，左右拖拽调整），`VERTICAL`为纵向排列（水平分割条，上下拖拽调整）
	 */
	public var direction(get, set):Direction;

	private function get_direction():Direction {
		return cast(this.layout, hx.layout.SplitterLayout).direction;
	}

	private function set_direction(value:Direction):Direction {
		cast(this.layout, hx.layout.SplitterLayout).direction = value;
		return value;
	}
}
