package test;

#if hxmaker_collision_checks
import hx.collision3d.BoxCollider3D;
import hx.collision3d.CollisionWorld3D;
import hx.controls3d.CharacterController3D;
import hx.display.Node3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;

/** 仅在用户显式启用时执行，不需要渲染后端；不代替实际画面验收。 */
class CollisionChecks {
	private static var count:Int;
	public static function run():Void {
		count = 0; queries(); movement(); trace("HXMAKER_COLLISION_CHECKS PASS 检查数："+count);
	}
	private static function add(world:CollisionWorld3D,w:Float,h:Float,d:Float,x:Float,y:Float,z:Float):BoxCollider3D {
		var value = new BoxCollider3D(w,h,d); value.offset.setTo(x,y,z); world.add(value); return value;
	}
	private static function disposeWorld(world:CollisionWorld3D):Void { for (value in world.colliders) value.dispose(); world.dispose(); }
	private static function queries():Void {
		var world = new CollisionWorld3D(), node = new Node3D(), box = add(world,2,2,2,0,0,0);
		try {
			var hit = world.raycast(new Ray3D(new Vector3D(-5,0,0),new Vector3D(10,0,0)));
			near(hit.distance,4,"射线使用世界距离"); near(hit.normal.x,-1,"射线进入面法线");
			expect(world.raycast(new Ray3D(new Vector3D(-5,0,0),new Vector3D(1,0,0)),3) == null,"射线最大距离");
			expect(world.raycast(new Ray3D(new Vector3D(),new Vector3D(1,0,0))).distance == 0,"射线起点在箱内");
			expect(world.overlapSphere(new Vector3D(1.8,0,1.8),1).length == 0,"球体圆角不能用扩展 AABB 的方角代替");
			expect(world.overlapCapsule(new Vector3D(1.8,0,1.8),1,4).length == 0,"胶囊圆角查询");
			expect(world.overlapCapsule(new Vector3D(1.5,2.5,0),1,4).length == 1,"竖直中心线端部与箱角重叠");
			hit = world.sweepSphere(new Vector3D(-5,0,0),0.5,new Vector3D(10,0,0)); near(hit.distance,3.5,"整段球体扫掠"); near(hit.fraction,0.35,"扫掠比例");
			expect(world.sweepSphere(new Vector3D(-1.5,0,0),0.5,new Vector3D(-2,0,0)) == null,"接触后背离不会被粘住");
			box.layer = 2; expect(world.overlapSphere(new Vector3D(),1,1).length == 0,"查询掩码过滤");
			box.isTrigger = true; expect(world.overlapSphere(new Vector3D(),1,2).length == 0,"触发代理默认不阻挡");
			expect(world.overlapSphere(new Vector3D(),1,2,true).length == 1,"显式包含触发代理");
			box.isTrigger = false; box.node = node; node.rotationY = 45; node.visible = false;
			near(box.getWorldBounds().max.x,Math.sqrt(2),"旋转箱代理使用世界 AABB");
			expect(world.overlapSphere(new Vector3D(),0.2).length == 1,"隐藏渲染节点不自动禁用碰撞");
			node.dispose(); expect(world.overlapSphere(new Vector3D(),0.2).length == 0,"已销毁绑定节点不再参与查询");
			failure(function() { world.overlapCapsule(new Vector3D(),1,1); },"拒绝低于直径的胶囊高度");
			world.clear(); expect(box.world == null && !box.isDisposed,"世界 clear 只注销借用代理"); box.dispose();
			world.dispose(); failure(function() { world.overlapSphere(new Vector3D(),1); },"销毁后的世界拒绝查询");
		} catch (error:Dynamic) { disposeWorld(world); box.dispose(); node.dispose(); throw error; }
		disposeWorld(world); box.dispose(); node.dispose();
	}
	private static function movement():Void {
		var world = new CollisionWorld3D(), parent = new Node3D(), node = new Node3D();
		parent.setPosition(3,0,-2); parent.rotationY = 30; parent.setScale(-2,1,0.5); parent.addChild(node);
		add(world,100,1,100,0,-0.5,0); var wall = add(world,0.1,5,20,0,2.5,0);
		var control = new CharacterController3D(world,node,0.5,2);
		try {
			control.teleport(new Vector3D(-2,0.003,0)); var result = control.move(new Vector3D(10,0,2));
			near(control.position.x,-0.552,"高速请求被薄墙阻挡"); near(control.position.z,2,"剩余位移沿墙滑动");
			expect(result.blocked && result.grounded && !result.stuck,"阻挡与落地状态");
			near(node.getWorldPosition().x,control.position.x,"父变换下应用世界位置 X"); near(node.getWorldPosition().z,2,"父变换下应用世界位置 Z");
			control.teleport(new Vector3D(-2,5,0)); result = control.update(1,new Vector3D());
			near(control.position.y,control.skinWidth,"大时间步长下落仍停在地面"); expect(result.grounded && control.verticalVelocity == 0,"落地清除向下速度");
			add(world,2,0.1,2,-2,2.6,0); expect(control.jump(6),"落地后可以起跳"); expect(!control.jump(6),"空中不重复起跳");
			control.update(0.1,new Vector3D()); result = control.update(0.1,new Vector3D());
			expect(result.hitCeiling && control.verticalVelocity == 0,"顶板接触清除向上速度");
			control.update(1,new Vector3D()); expect(control.grounded,"顶板接触后重新落地");
			control.teleport(new Vector3D(0,0,0)); result = control.move(new Vector3D());
			expect(!result.stuck && Math.abs(control.position.x) >= 0.55,"初始墙内重叠被推出");
			wall.layer = 2; control.collisionMask = 1; control.teleport(new Vector3D(-2,0,4)); control.move(new Vector3D(10,0,0));
			near(control.position.x,8,"角色掩码可忽略指定层"); wall.layer = 1; control.collisionMask = -1;
			add(world,0.1,5,20,-1,2.5,0); control.teleport(new Vector3D(-0.5,0,5)); result = control.move(new Vector3D(20,0,0));
			expect(result.stuck,"无法容纳胶囊的间隙明确报告 stuck");
			var before = control.position;
			failure(function() { control.update(-1,new Vector3D()); },"拒绝负时间步长"); near(control.position.x,before.x,"参数错误前不修改位置");
			control.dispose(); expect(!world.isDisposed && !node.isDisposed,"控制器不销毁借用世界或节点");
			failure(function() { control.move(new Vector3D()); },"销毁后的控制器拒绝运动");
		} catch (error:Dynamic) { control.dispose(); disposeWorld(world); parent.dispose(); throw error; }
		control.dispose(); disposeWorld(world); parent.dispose();
	}
	private static function near(actual:Float,expected:Float,label:String):Void { expect(Math.isFinite(actual) && Math.abs(actual-expected) < 1e-4,label); }
	private static function expect(value:Bool,label:String):Void { if (!value) throw "碰撞数值检查失败："+label; count++; }
	private static function failure(callback:Void->Void,label:String):Void { var caught = false; try { callback(); } catch (_:Dynamic) { caught = true; } expect(caught,label); }
}
#end
