package hx.collision3d;

import hx.display.Node3D;
import hx.geom.Bounds3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;

/** 碰撞代理公共基类；由业务拥有，碰撞世界仅借用注册。 */
class Collider3D {
	/** 业务名称，不要求唯一。 */
	public var name:String;

	/** 代理在节点局部坐标中的偏移；无节点时作为世界偏移。 */
	public var offset:Vector3D = new Vector3D();

	/** 可选的借用三维节点；不挂到显示树也可查询，代理不销毁节点。 */
	public var node:Node3D;

	/** 非零碰撞层位掩码，默认 1；查询 mask 按位相交时参与。 */
	public var layer:Int = 1;

	/** 是否参与碰撞世界查询，默认 true。 */
	public var enabled:Bool = true;

	/** 是否为仅查询触发器，默认 false；普通角色运动忽略触发器。 */
	public var isTrigger:Bool = false;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 当前注册的借用碰撞世界；未注册或已注销时为 null。 */
	public var world(default, null):CollisionWorld3D;

	/** 创建未注册代理并借用可选节点；派生类需实现形状查询。 */
	public function new(node:Node3D = null) {
		this.node = node;
	}

	/** 校验对象生命周期与参数范围；无效时抛出中文异常。 */
	public function validate():Void {
		if (isDisposed)
			throw "碰撞体已经销毁";
		CollisionMath3D.vector(offset);
		if (layer == 0)
			throw "碰撞层位掩码不能为零";
	}

	/** 返回世界空间轴对齐包围盒，包含所属节点的变换。 */
	public function getWorldBounds():Bounds3D {
		throw "碰撞代理必须实现世界边界";
	}

	/** 计算世界竖直胶囊与代理的距离；高度包含两端半球，负分离量表示重叠。 */
	public function sampleCapsule(center:Vector3D, radius:Float, height:Float):CollisionSample3D {
		throw "碰撞代理必须实现胶囊距离";
	}

	/** 查询世界射线最近命中；最大距离从射线起点计算，无命中返回 null。 */
	public function raycast(ray:Ray3D, maxDistance:Float):CollisionHit3D {
		throw "碰撞代理必须实现射线查询";
	}

	@:allow(hx.collision3d.CollisionWorld3D)
	private function setWorld(value:CollisionWorld3D):Void {
		world = value;
	}

	/** 幂等从碰撞世界注销并解除节点引用，不销毁节点。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		if (world != null)
			world.remove(this);
		isDisposed = true;
		node = null;
	}
}
