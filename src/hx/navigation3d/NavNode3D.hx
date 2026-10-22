package hx.navigation3d;

import hx.geom.Vector3D;

/** 路点由所属图创建并持有；世界位置代表角色脚底，读取位置返回副本。 */
class NavNode3D {
	/** 图内唯一编号；移除节点后不复用。 */
	public var id(default, null):Int;

	/** 项目自定义名称，不要求唯一。 */
	public var name:String;

	/** 所属图；节点被移除或图被销毁后为 null。 */
	public var graph(default, null):NavGraph3D;

	/** 世界脚底坐标副本；修改路点请调用图的 moveNode。 */
	public var position(get, never):Vector3D;

	/** 是否参与搜索；切换时增加图版本。 */
	public var enabled(get, set):Bool;

	private var point:Vector3D;
	private var active:Bool = true;

	@:allow(hx.navigation3d.NavGraph3D)
	private function new(graph:NavGraph3D, id:Int, position:Vector3D, name:String) {
		this.graph = graph;
		this.id = id;
		this.point = position.clone();
		this.name = name;
	}

	private function get_position():Vector3D {
		return point.clone();
	}

	private function get_enabled():Bool {
		return active;
	}

	private function set_enabled(value:Bool):Bool {
		if (graph == null)
			throw "导航节点已经移除";
		if (value != active) {
			active = value;
			graph.touch();
		}
		return value;
	}

	@:allow(hx.navigation3d.NavGraph3D)
	private function move(position:Vector3D):Void {
		point = position.clone();
	}

	@:allow(hx.navigation3d.NavGraph3D)
	private function detach():Void {
		graph = null;
	}
}
