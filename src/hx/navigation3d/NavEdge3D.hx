package hx.navigation3d;

/** 有向通路；双向连接由两条独立边组成，门开关时应同步设置两条边。 */
class NavEdge3D {
	/** 借用的起点。 */
	public var from(default, null):NavNode3D;

	/** 借用的终点。 */
	public var to(default, null):NavNode3D;

	/** 通行成本，非负有限；null 表示随节点位置计算的世界距离。 */
	public var cost(get, set):Null<Float>;

	/** 是否通行；切换时增加图版本。 */
	public var enabled(get, set):Bool;

	/** 所属图；断开后为 null。 */
	public var graph(default, null):NavGraph3D;

	private var weight:Null<Float>;
	private var active:Bool = true;

	@:allow(hx.navigation3d.NavGraph3D)
	private function new(graph:NavGraph3D, from:NavNode3D, to:NavNode3D, cost:Null<Float>) {
		this.graph = graph;
		this.from = from;
		this.to = to;
		weight = cost;
	}

	private function get_cost():Null<Float> {
		return weight;
	}

	private function set_cost(value:Null<Float>):Null<Float> {
		if (graph == null)
			throw "导航连接已经断开";
		NavGraph3D.checkCost(value);
		if (weight != value) {
			weight = value;
			graph.touch();
		}
		return value;
	}

	private function get_enabled():Bool {
		return active;
	}

	private function set_enabled(value:Bool):Bool {
		if (graph == null)
			throw "导航连接已经断开";
		if (active != value) {
			active = value;
			graph.touch();
		}
		return value;
	}

	/** 返回当前实际成本；默认成本使用三维距离。 */
	public function getCost():Float {
		return weight == null ? from.position.subtract(to.position).length : weight;
	}

	@:allow(hx.navigation3d.NavGraph3D)
	private function detach():Void {
		graph = null;
	}
}
