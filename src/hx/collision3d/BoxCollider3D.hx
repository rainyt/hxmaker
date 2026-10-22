package hx.collision3d;

import hx.display3d.Node3D;
import hx.geom.Bounds3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 显式箱形代理；节点只提供变换，旋转后的代理使用保守世界 AABB。 */
class BoxCollider3D extends Collider3D {
	/** 局部宽、高、深，均为正有限数值；修改后查询自动使用新尺寸。 */
	public var size:Vector3D;

	/** 创建以局部原点为中心的箱体代理；借用可选节点，旋转后采用保守世界 AABB。 */
	public function new(width:Float, height:Float, depth:Float, node:Node3D = null) {
		super(node);
		size = new Vector3D(width, height, depth);
		validate();
	}

	/** 校验对象生命周期与参数范围；无效时抛出中文异常。 */
	override public function validate():Void {
		super.validate();
		if (size == null || offset == null)
			throw "碰撞体尺寸与偏移不能为空";
		for (value in [size.x, size.y, size.z, offset.x, offset.y, offset.z])
			if (!Math3D.finite(value))
				throw "碰撞体参数必须有限";
		if (size.x <= 0 || size.y <= 0 || size.z <= 0 || layer == 0)
			throw "碰撞体尺寸必须为正，层位掩码不能为零";
	}

	/** 返回世界空间轴对齐包围盒，包含所属节点的变换。 */
	override public function getWorldBounds():Bounds3D {
		validate();
		if (node != null && node.isDisposed)
			throw "碰撞体绑定节点已经销毁";
		var local = new Bounds3D();
		local.include(offset.x - size.x / 2, offset.y - size.y / 2, offset.z - size.z / 2);
		local.include(offset.x + size.x / 2, offset.y + size.y / 2, offset.z + size.z / 2);
		var result = node == null ? local : local.transformed(node.getWorldMatrix());
		for (value in [
			result.min.x,
			result.min.y,
			result.min.z,
			result.max.x,
			result.max.y,
			result.max.z
		])
			if (!Math3D.finite(value))
				throw "碰撞体世界边界超出有限范围";
		return result;
	}

	/** 计算世界竖直胶囊与代理的距离；高度包含两端半球，负分离量表示重叠。 */
	override public function sampleCapsule(center:Vector3D, radius:Float, height:Float):CollisionSample3D {
		var sample = CollisionMath3D.sample(center, radius, height, getWorldBounds());
		// 胶囊贴到箱顶边缘时，区分圆角接触方向与实际支撑面方向。
		if (sample.normal.y > 1e-8)
			sample.surfaceNormal = new Vector3D(0, 1, 0);
		return sample;
	}

	/** 查询世界射线最近命中；最大距离从射线起点计算，无命中返回 null。 */
	override public function raycast(ray:Ray3D, maxDistance:Float):CollisionHit3D {
		var box = getWorldBounds(), near = 0., far = maxDistance, normal = new Vector3D();
		var origin = [ray.origin.x, ray.origin.y, ray.origin.z],
			direction = [ray.direction.x, ray.direction.y, ray.direction.z];
		var lo = [box.min.x, box.min.y, box.min.z],
			hi = [box.max.x, box.max.y, box.max.z];
		for (axis in 0...3) {
			if (Math.abs(direction[axis]) < 1e-12) {
				if (origin[axis] < lo[axis] || origin[axis] > hi[axis])
					return null;
			} else {
				var a = (lo[axis] - origin[axis]) / direction[axis],
					b = (hi[axis] - origin[axis]) / direction[axis];
				var entry = Math.min(a, b), exit = Math.max(a, b);
				if (entry > near) {
					near = entry;
					normal.setTo(0, 0, 0);
					var sign = direction[axis] > 0 ? -1 : 1;
					if (axis == 0)
						normal.x = sign;
					else if (axis == 1)
						normal.y = sign;
					else
						normal.z = sign;
				}
				far = Math.min(far, exit);
				if (near > far)
					return null;
			}
		}
		if (!Math3D.finite(near))
			return null;
		if (normal.length == 0)
			normal = CollisionMath3D.sample(ray.origin, 0, 0, box).normal;
		return new CollisionHit3D(this, ray.at(near), normal, near);
	}
}
