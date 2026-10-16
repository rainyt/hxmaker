package hx.collision3d;

import hx.display.Node3D;
import hx.geom.Bounds3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;

/** 碰撞代理公共基类；由业务拥有，碰撞世界仅借用注册。 */
class Collider3D {
	public var name:String;
	public var offset:Vector3D = new Vector3D();
	public var node:Node3D;
	public var layer:Int = 1;
	public var enabled:Bool = true;
	public var isTrigger:Bool = false;
	public var isDisposed(default, null):Bool = false;
	public var world(default, null):CollisionWorld3D;
	public function new(node:Node3D = null) { this.node = node; }
	public function validate():Void {
		if (isDisposed) throw "碰撞体已经销毁";
		CollisionMath3D.vector(offset); if (layer == 0) throw "碰撞层位掩码不能为零";
	}
	public function getWorldBounds():Bounds3D { throw "碰撞代理必须实现世界边界"; }
	public function sampleCapsule(center:Vector3D,radius:Float,height:Float):CollisionSample3D { throw "碰撞代理必须实现胶囊距离"; }
	public function raycast(ray:Ray3D,maxDistance:Float):CollisionHit3D { throw "碰撞代理必须实现射线查询"; }
	@:allow(hx.collision3d.CollisionWorld3D)
	private function setWorld(value:CollisionWorld3D):Void { world = value; }
	public function dispose():Void {
		if (isDisposed) return;
		if (world != null) world.remove(this);
		isDisposed = true; node = null;
	}
}
