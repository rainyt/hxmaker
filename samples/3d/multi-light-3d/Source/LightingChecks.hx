package;

import hx.display.Scene3D;
import hx.display3d.Node3D;
import hx.light.DirectionalLight3D;
import hx.light.PointLight3D;
import hx.light.SpotLight3D;

/** 手动调用的无 GPU 参数与场景关系检查，不在示例启动时执行。 */
class LightingChecks {
	public static function run():Void {
		var scene = new Scene3D(), other = new Scene3D();
		try {
			var sun = new DirectionalLight3D(), point = new PointLight3D(), spot = new SpotLight3D();
			var parent = new Node3D(); scene.root.addChild(parent);
			scene.root.addChild(sun); scene.light = sun; scene.addLight(sun);
			parent.addChild(point); scene.addLight(point); scene.addLight(point);
			scene.root.addChild(spot); scene.addLight(spot);
			check(scene.getActiveLights().length == 3, "重复注册及主光去重");
			check(scene.getActiveLights()[0] == sun, "主方向光优先");
			var snapshot = scene.lights; snapshot.resize(0);
			check(scene.lights.length == 3, "灯光集合副本隔离");
			var key = scene.lightingKey(); parent.x = 3;
			check(key != scene.lightingKey(), "父节点移动使光照键变化");
			parent.visible = false;
			check(scene.getActiveLights().length == 2, "隐藏父节点排除点光"); parent.visible = true;
			point.intensity = 0; check(scene.getActiveLights().length == 2, "零强度灯不占名额"); point.intensity = 1;
			expectFailure(function() { other.addLight(point); }, "不能注册其他场景的灯光");
			point.range = 0; expectFailure(function() { scene.lightingKey(); }, "拒绝零范围"); point.range = 10;
			spot.innerAngle = spot.outerAngle;
			expectFailure(function() { scene.lightingKey(); }, "拒绝重合锥角"); spot.innerAngle = 18;
			spot.outerAngle = Math.NaN;
			expectFailure(function() { scene.lightingKey(); }, "拒绝非有限锥角"); spot.outerAngle = 30;
			point.intensity = -1;
			expectFailure(function() { scene.lightingKey(); }, "拒绝负强度"); point.intensity = 1;
			other.root.addChild(point); check(scene.getActiveLights().length == 2, "移出场景排除灯光");
			spot.dispose(); check(scene.getActiveLights().length == 1, "销毁排除灯光");
			scene.removeLight(sun); scene.light = null;
			check(scene.getActiveLights().length == 0, "移除全部有效灯光");
		} catch (error:Dynamic) { scene.dispose(); other.dispose(); throw error; }
		scene.dispose(); other.dispose();
	}
	private static function check(value:Bool, message:String):Void { if (!value) throw "光照检查失败：" + message; }
	private static function expectFailure(callback:Void->Void, message:String):Void {
		var failed = false; try { callback(); } catch (_:Dynamic) { failed = true; }
		check(failed, message);
	}
}
