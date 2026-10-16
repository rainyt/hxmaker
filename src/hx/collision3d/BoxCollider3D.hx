package hx.collision3d;

import hx.display.Node3D;
import hx.geom.Bounds3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 显式箱形代理；节点只提供变换，旋转后的代理使用保守世界 AABB。 */
class BoxCollider3D {
	public var name:String;
	public var size:Vector3D;
	public var offset:Vector3D = new Vector3D();
	public var node:Node3D;
	public var layer:Int = 1;
	public var enabled:Bool = true;
	public var isTrigger:Bool = false;
	public var isDisposed(default, null):Bool = false;
	public var world(default, null):CollisionWorld3D;
	public function new(width:Float, height:Float, depth:Float, node:Node3D = null) {
		size = new Vector3D(width,height,depth); this.node = node; validate();
	}
	public function validate():Void {
		if (isDisposed) throw "箱形碰撞体已经销毁";
		if (size == null || offset == null) throw "碰撞体尺寸与偏移不能为空";
		for (value in [size.x,size.y,size.z,offset.x,offset.y,offset.z]) if (!Math3D.finite(value)) throw "碰撞体参数必须有限";
		if (size.x <= 0 || size.y <= 0 || size.z <= 0 || layer == 0) throw "碰撞体尺寸必须为正，层位掩码不能为零";
	}
	public function getWorldBounds():Bounds3D {
		validate();
		if (node != null && node.isDisposed) throw "碰撞体绑定节点已经销毁";
		var local = new Bounds3D();
		local.include(offset.x-size.x/2,offset.y-size.y/2,offset.z-size.z/2);
		local.include(offset.x+size.x/2,offset.y+size.y/2,offset.z+size.z/2);
		var result = node == null ? local : local.transformed(node.getWorldMatrix());
		for (value in [result.min.x,result.min.y,result.min.z,result.max.x,result.max.y,result.max.z])
			if (!Math3D.finite(value)) throw "碰撞体世界边界超出有限范围";
		return result;
	}
	@:allow(hx.collision3d.CollisionWorld3D)
	private function setWorld(value:CollisionWorld3D):Void { world = value; }
	/** 注销碰撞体，不销毁借用的节点、几何或材质。 */
	public function dispose():Void {
		if (isDisposed) return;
		if (world != null) world.remove(this);
		isDisposed = true; node = null;
	}
}
