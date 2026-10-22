import hx.display3d.Camera3D;
import hx.geom.Bounds3D;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;
import hx.light.ShadowFilter3D;
import hx.light.ShadowQuality3D;
import hx.render3d.DirectionalShadowPlanner3D;
import hx.render3d.DirectionalShadowSettings3D;

/** 自动阴影规划的数值验收入口；本轮仅准备代码，未运行。 */
class DirectionalShadowPlannerChecks {
	static function main():Void {
		var camera = new Camera3D(); camera.near = 0.5; camera.far = 1000;
		camera.setPosition(0, 4.5, 11); camera.lookAt(new Vector3D(0, 0.3, 0));
		var light = new DirectionalLight3D(); light.direction = new Vector3D(-0.5, -1, -0.8);
		var planner = new DirectionalShadowPlanner3D();
		var caster = box(-4,0.05,-3,4,2.5,3), floor = box(-40,0,-40,40,0,40);
		var plan = planner.plan(camera,912/370,light,[caster],[floor],0);
		check(plan.count == 1 && plan.lightBounds != null, "紧凑场景自动单级，不需要手写范围");
		var size = plan.settings.tileSize(plan.count);
		check(size*size*plan.count*8 <= plan.settings.budgetBytes, "自动配置遵守总附件预算");
		var matrix = plan.projections(size,1)[0];
		camera.setPosition(11,4.5,0); camera.lookAt(new Vector3D(0,0.3,0));
		var rotated = planner.plan(camera,912/370,light,[caster],[floor],0.1).projections(size,1)[0];
		for (i in 0...16) check(Math.abs(matrix.rawData[i]-rotated.rawData[i]) < 1e-6, "固定展示的环绕取景稳定");
		var explicitKey = light.settingsKey();
		light.shadowMapSize = 1024;
		check(light.hasShadowOverride("shadowMapSize") && explicitKey != light.settingsKey(), "与旧默认值相同的显式赋值也被记录");
		light.shadowQuality = ShadowQuality3D.HIGH;
		var settings = new DirectionalShadowSettings3D(light);
		check(settings.tileSize(1) == 1024 && settings.filter == ShadowFilter3D.PCF9, "显式尺寸优先，未覆盖的过滤跟随质量档位");
		light.shadowFilter = ShadowFilter3D.PCF4;
		check(new DirectionalShadowSettings3D(light).filter == ShadowFilter3D.PCF4, "质量档位不覆盖显式过滤");
		light.resetShadowOverrides("shadowMapSize");
		check(!light.hasShadowOverride("shadowMapSize") && new DirectionalShadowSettings3D(light).tileSize(1) == 2048, "单项恢复自动配置");
		light.shadowDistance = 40; light.shadowCascadeCount = 2;
		plan = planner.plan(camera,912/370,light,[caster],[floor],0.2);
		check(plan.count == 2 && plan.lightBounds == null && plan.distance == 40, "显式距离和级联数量保留相机模式");
		var fallback = plan.projections(1024,1)[0];
		check(caster.inFrustum(fallback), "降为单级时保留完整范围投影");
		light.shadowBias = 0.0001; light.shadowSlopeBias = 0.0005;
		settings = new DirectionalShadowSettings3D(light);
		check(settings.depthBias(0.01,10,24,false) == 0.0001, "显式深度偏差保留原单位");
		light.resetShadowOverrides(); light.shadowQuality = ShadowQuality3D.LEGACY;
		settings = new DirectionalShadowSettings3D(light);
		check(!settings.adaptive && settings.tileSize(2) == 1024 && settings.distance == 100, "传统档位保留旧的默认配置");
		light.shadowQuality = ShadowQuality3D.BALANCED;
		settings = new DirectionalShadowSettings3D(light);
		check(Math.abs(settings.depthBias(0.01,10,24,false)-settings.depthBias(1,1000,24,false)) < 1e-12,
			"几何与深度同比缩放时自动偏差保持一致");
		// 镜头外上游物体应沿光空间列保留，不能直接使用主相机可见列表作为投影列表。
		var upstream = box(-4,20,-3,4,22,3);
		light.direction = new Vector3D(0,-1,0);
		plan = planner.plan(camera,912/370,light,[caster,upstream],[floor],1);
		check(upstream.inFrustum(plan.projections(plan.settings.tileSize(plan.count),plan.count)[0]), "保留镜头外上游投影物");
		camera.dispose(); light.dispose();
		trace("HXMAKER_DIRECTIONAL_SHADOW_PLANNER_CHECKS PASS");
	}
	private static function box(x:Float,y:Float,z:Float,mx:Float,my:Float,mz:Float):Bounds3D {
		var result = new Bounds3D(); result.include(x,y,z); result.include(mx,my,mz); return result;
	}
	private static function check(value:Bool,message:String):Void { if (!value) throw "阴影规划检查失败："+message; }
}
