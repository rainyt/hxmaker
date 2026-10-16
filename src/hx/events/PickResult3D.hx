package hx.events;

import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Node3D;
import hx.geom.Vector3D;
import hx.geom.Point;

/** 几何拾取结果，不包含纹理 Alpha 像素检测。 */
class PickResult3D {
	/** 命中的网格借用引用。 */
	public var object:MeshObject;

	/** 世界空间命中位置。 */
	public var position:Vector3D;

	/** 从世界射线起点到命中的距离；视口射线起点为近裁剪面。 */
	public var distance:Float;

	/** 命中三角形在几何索引数组中的三元组编号。 */
	public var triangleIndex:Int;

	/** 按重心坐标插值后的网格 UV。 */
	public var uv:Point;

	/** 最近的所属模型；骨骼挂点附件同样沿父链解析，无所属模型时为 null。 */
	public var model(get, never):Model3D;

	private function get_model():Model3D {
		var node:Node3D = object;
		while (node != null) {
			if (Std.isOfType(node, Model3D))
				return cast node;
			node = node.parent;
		}
		return null;
	}

	/** 保存网格命中数据，不转移网格或模型所有权。 */
	public function new(object:MeshObject, position:Vector3D, distance:Float, triangleIndex:Int, uv:Point) {
		this.object = object;
		this.position = position;
		this.distance = distance;
		this.triangleIndex = triangleIndex;
		this.uv = uv;
	}
}
