package test;

#if hxmaker_terrain_checks
import hx.collision3d.BoxCollider3D;
import hx.collision3d.CollisionWorld3D;
import hx.collision3d.RampCollider3D;
import hx.controls3d.CharacterController3D;
import hx.display.Node3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;

/** 用户显式启用的地形数值验收；本文件的存在不代表已经运行或通过。 */
class TerrainChecks {
	private static var count:Int;
	public static function run():Void { count = 0; rampQueries(); stairs(); slopes(); trace("HXMAKER_TERRAIN_CHECKS PASS 检查数："+count); }
	private static function cleanup(world:CollisionWorld3D):Void { for (value in world.colliders) value.dispose(); world.dispose(); }
	private static function box(world:CollisionWorld3D,w:Float,h:Float,d:Float,x:Float,y:Float,z:Float):BoxCollider3D {
		var value = new BoxCollider3D(w,h,d); value.offset.setTo(x,y,z); return world.add(value);
	}
	private static function rampQueries():Void {
		var world = new CollisionWorld3D(), node = new Node3D(), ramp = new RampCollider3D(4,2,4); world.add(ramp);
		try {
			var hit = world.raycast(new Ray3D(new Vector3D(0,10,0),new Vector3D(0,-1,0)));
			near(hit.point.y,1,"射线命中真实斜面"); near(hit.surfaceNormal.y,2/Math.sqrt(5),"斜面支撑法线");
			expect(world.overlapSphere(new Vector3D(0,1.8,-1.5),0.1).length == 0,"坡道 AABB 内的空区域不能成为碰撞实体");
			hit = world.sweepCapsule(new Vector3D(0,5,0),0.5,2,new Vector3D(0,-10,0));
			near(hit.distance,5-(1+0.5+0.5*Math.sqrt(5)/2),"竖直胶囊连续命中斜面");
			near(hit.surfaceNormal.y,2/Math.sqrt(5),"扫掠携带真实坡面法线");
			ramp.layer = 2; expect(world.raycast(new Ray3D(new Vector3D(0,10,0),new Vector3D(0,-1,0)),20,1) == null,"坡道碰撞层过滤"); ramp.layer = 1;
			ramp.node = node; node.setPosition(3,0,4); node.rotationY = 90; node.setScale(-1,2,0.5);
			hit = world.raycast(new Ray3D(new Vector3D(3,10,4),new Vector3D(0,-1,0)));
			near(hit.point.y,2,"变换后的坡面高度"); near(hit.normal.y,1/Math.sqrt(5),"非均匀及负缩放下的坡面法线");
			node.y = 1; hit = world.raycast(new Ray3D(new Vector3D(3,10,4),new Vector3D(0,-1,0))); near(hit.point.y,3,"节点变化刷新代理缓存");
			ramp.size.y = 3; hit = world.raycast(new Ray3D(new Vector3D(3,10,4),new Vector3D(0,-1,0))); near(hit.point.y,4,"尺寸变化刷新代理缓存");
			node.scaleX = 0; failure(function() { ramp.getWorldBounds(); },"拒绝退化坡道变换");
		} catch (error:Dynamic) { cleanup(world); node.dispose(); throw error; }
		cleanup(world); node.dispose();
	}
	private static function stairs():Void {
		var world = new CollisionWorld3D(), node = new Node3D(); box(world,30,1,30,0,-0.5,0);
		var step = box(world,4,0.4,2,0,0.2,1), control = new CharacterController3D(world,node);
		control.stepOffset = 0.45; control.groundSnapDistance = 0.45;
		try {
			control.teleport(new Vector3D(0,0,-1)); var result = control.move(new Vector3D(0,0,1.5));
			expect(result.stepped && result.grounded && !result.stuck,"有支撑时跨上合格台阶"); near(control.position.y,0.402,"跨步落脚高度");
			near(control.position.z,0.5,"跨步不超出请求的水平位移");
			result = control.move(new Vector3D(0,0,-2)); expect(result.grounded,"下台阶保持贴地"); near(control.position.y,0.002,"下台阶落回地面");
			var ceiling = box(world,4,0.2,4,0,2.3,0); control.teleport(new Vector3D(0,0,-1)); result = control.move(new Vector3D(0,0,1.5));
			expect(!result.stepped && control.position.z < 0,"头顶空间不足时不能穿顶跨步"); ceiling.dispose();
			step.size.y = 0.85; step.offset.y = 0.425; control.teleport(new Vector3D(0,0,-1)); result = control.move(new Vector3D(0,0,1.5));
			expect(!result.stepped && control.position.z < 0,"高于跨步上限的障碍继续阻挡");
			control.teleport(new Vector3D(0,0.2,-1)); result = control.move(new Vector3D(0,0,1.5)); expect(!result.stepped,"没有地面支撑时不跨步");
			step.size.y = 0.4; step.offset.y = 0.2; control.stepOffset = 0; control.teleport(new Vector3D(0,0,-1)); result = control.move(new Vector3D(0,0,1.5));
			expect(!result.stepped && control.position.z < 0,"零跨步配置保留阻挡");
			failure(function() { control.maxSlopeAngle = 90; },"拒绝九十度坡度上限");
			control.stepOffset = -1; failure(function() { control.move(new Vector3D()); },"拒绝负跨步高度");
		} catch (error:Dynamic) { control.dispose(); cleanup(world); node.dispose(); throw error; }
		control.dispose(); cleanup(world); node.dispose();
	}
	private static function slopes():Void {
		var world = new CollisionWorld3D(), node = new Node3D(); box(world,50,1,50,0,-0.5,0);
		var ramp = new RampCollider3D(4,2,5); ramp.offset.z = 2.5; world.add(ramp);
		var control = new CharacterController3D(world,node); control.stepOffset = 0.45; control.maxSlopeAngle = 45; control.groundSnapDistance = 0.3;
		try {
			control.teleport(new Vector3D(0,0,-1));
			for (i in 0...120) control.update(1/60,new Vector3D(0,0,2));
			expect(control.position.z > 2 && control.position.y > 0.8 && control.grounded,"角色能沿可行走缓坡上行");
			var before = control.position; for (i in 0...60) control.update(1/60,new Vector3D());
			near(control.position.y,before.y,"缓坡站立无垂直漂移"); near(control.position.z,before.z,"缓坡站立不缓慢下滑");
			for (i in 0...120) control.update(1/60,new Vector3D(0,0,-2));
			expect(control.position.z < 0 && control.grounded,"缓坡下行后回到地面");
			ramp.size.y = 4; ramp.size.z = 2; ramp.offset.z = 1; control.teleport(new Vector3D(0,0,-1));
			var limited = false;
			for (i in 0...90) if (control.update(1/60,new Vector3D(0,0,2)).slopeLimited) limited = true;
			expect(limited && control.position.z < 0.1,"超过坡度上限时不能向上爬坡");
			control.maxSlopeAngle = 70; control.teleport(new Vector3D(0,0,-1));
			for (i in 0...90) control.update(1/60,new Vector3D(0,0,2));
			expect(control.position.z > 0.5 && control.position.y > 1,"提高允许坡度后可上行");
		} catch (error:Dynamic) { control.dispose(); cleanup(world); node.dispose(); throw error; }
		control.dispose(); cleanup(world); node.dispose();
	}
	private static function near(actual:Float,expected:Float,label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual-expected) < 1e-4,label); }
	private static function expect(value:Bool,label:String):Void { if (!value) throw "地形数值检查失败："+label; count++; }
	private static function failure(callback:Void->Void,label:String):Void { var caught = false; try { callback(); } catch (_:Dynamic) { caught = true; } expect(caught,label); }
}
#end
