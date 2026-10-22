import hx.display3d.Camera3D;
import hx.geom.Bounds3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;
import hx.render3d.DirectionalShadowFit3D;
import hx.render3d.Math3D;

/** 自动阴影取景与可选质量参数的纯数值检查。 */
class DirectionalShadowFitChecks {
	static function main():Void {
		var camera = new Camera3D();
		camera.near = 1; camera.far = 100;
		var direction = new Vector3D(0, -1, 0);
		var fit = new DirectionalShadowFit3D(camera, 1, 10, direction);
		var local = box(-1, -1, -6, 1, 1, -4);
		var distant = box(999, -1, -6, 1001, 1, -4);
		var upstream = box(-1, 19, -6, 1, 21, -4);
		var downstream = box(-1, -101, -6, 1, -99, -4);
		check(fit.affects(local), "保留局部投影物");
		check(!fit.affects(distant), "无关远处投影物不影响局部覆盖区");
		check(!upstream.inFrustum(camera.getViewProjection(1)) && fit.affects(upstream), "保留镜头外但向画面内投影的上游物体");
		check(!fit.affects(downstream), "下游物体不能遮挡覆盖区");
		var projection = fit.projection([local], 0.1, 2048);
		same(projection, fit.projection([local, distant], 0.1, 2048), "远离物体不改变阴影矩阵");
		var upstreamProjection = fit.projection([local, upstream], 0.1, 2048);
		// 光空间 XY 对应的矩阵行不随上游深度增加而变化。
		for (i in [0, 4, 8, 12, 1, 5, 9, 13]) near(projection.rawData[i], upstreamProjection.rawData[i], "上游物体只扩展深度");
		var upstreamPoint = Math3D.project(upstreamProjection, 0, 20, -5);
		check(Math.abs(upstreamPoint.z) <= 1, "上游物体进入阴影深度范围");
		var noPadding = fit.projection([], 0, 2048);
		var tangent = Math.tan(camera.fieldOfView * Math.PI / 360);
		for (depth in [1., 10.]) for (i in 0...4) {
			var extent = depth * tangent;
			var p = Math3D.project(noPadding, (i & 1) == 0 ? -extent : extent, (i & 2) == 0 ? -extent : extent, -depth);
			check(Math.abs(p.x) <= 1 + 1e-6 && Math.abs(p.y) <= 1 + 1e-6 && Math.abs(p.z) <= 1 + 1e-6,
				"无留边时纹素对齐仍完整覆盖截断视锥");
		}
		var span = fit.bounds.max.x - fit.bounds.min.x;
		for (yaw in [0., 45., 90., 135., 180.]) {
			camera.rotationY = yaw;
			var rotated = new DirectionalShadowFit3D(camera, 1, 10, direction);
			near(rotated.bounds.max.x - rotated.bounds.min.x, span, "相机旋转不改变阴影纹素尺度");
		}
		camera.rotationY = 0;
		var split = DirectionalShadowFit3D.splitDistance(1, 100), blendStart = split - (split - 1) * 0.15;
		check(split > 1 && split < 100 && blendStart < split, "有效的近远级联和交界混合区");
		var farFit = new DirectionalShadowFit3D(camera, 1, 100, direction, blendStart);
		var farProjection = farFit.projection([local], 0.1, 2048);
		var farPoint = Math3D.project(farProjection, 0, 0, -80);
		check(Math.abs(farPoint.x) <= 1 && Math.abs(farPoint.y) <= 1 && Math.abs(farPoint.z) <= 1, "远级联保留旧 30 单位范围以外的阴影接收区");
		camera.x = 2;
		var moved = new DirectionalShadowFit3D(camera, 1, 10, direction).projection([local], 0.1, 2048);
		check(Math.abs(moved.rawData[12] - projection.rawData[12]) > 1e-6, "自动取景跟随相机平移");
		near(DirectionalShadowFit3D.splitDistance(1, 101, 0.4), 41, "显式比例按整个近远深度区间切分");
		near(DirectionalShadowFit3D.splitDistance(1, 100, null), split, "null 保留旧的自动切分");
		for (invalid in [0., 1., -0.1, Math.NaN]) {
			var failed = false;
			try { DirectionalShadowFit3D.splitDistance(1, 100, invalid); } catch (_:Dynamic) { failed = true; }
			check(failed, "拒绝非法切分比例");
		}
		var light = new DirectionalLight3D(), key = light.settingsKey();
		light.shadowDistance = 20;
		check(light.settingsKey() != key, "距离变化使灯光设置缓存失效");
		light.shadowDistance = 0;
		light.settingsKey();
		check(light.shadowCascadeCount == 2, "级联请求的旧默认值保持可读取");
		light.shadowDistance = -1;
		var rejected = false;
		try { light.settingsKey(); } catch (_:Dynamic) { rejected = true; }
		check(rejected, "拒绝无效阴影距离");
		light.shadowDistance = 100; light.shadowCascadeCount = 3;
		rejected = false;
		try { light.settingsKey(); } catch (_:Dynamic) { rejected = true; }
		check(rejected, "拒绝不支持的级联数量");
		light.shadowCascadeCount = 1; light.shadowFadeRatio = 0; light.settingsKey();
		check(light.shadowFilter == hx.light.ShadowFilter3D.PCF4 && light.shadowCascadeSplit == null,
			"默认过滤和切分保持兼容");
		var previous = light.settingsKey();
		light.shadowFilter = hx.light.ShadowFilter3D.PCF9;
		check(previous != light.settingsKey(), "切换 PCF9 触发设置变化");
		previous = light.settingsKey(); light.shadowFilterRadius = 1.25;
		check(previous != light.settingsKey(), "半径变化触发设置变化");
		light.shadowFilterRadius = 0; light.shadowCascadeBlend = 0; light.shadowCascadeSplit = 0.4; light.settingsKey();
		light.shadowFilterRadius = 1.5; light.shadowCascadeBlend = 0.5; light.settingsKey();
		for (field in ["shadowFilterRadius", "shadowCascadeBlend", "shadowCascadeSplit"]) {
			for (invalid in [-1., Math.NaN, Math.POSITIVE_INFINITY, 2.]) {
				var original:Dynamic = Reflect.getProperty(light, field); Reflect.setProperty(light, field, invalid);
				var failed = false;
				try { light.settingsKey(); } catch (_:Dynamic) { failed = true; }
				Reflect.setProperty(light, field, original);
				check(failed, "拒绝非法可选阴影参数：" + field);
			}
		}
		camera.dispose(); light.dispose();
		trace("HXMAKER_DIRECTIONAL_SHADOW_FIT_CHECKS PASS");
	}
	private static function box(minX:Float, minY:Float, minZ:Float, maxX:Float, maxY:Float, maxZ:Float):Bounds3D {
		var result = new Bounds3D(); result.include(minX, minY, minZ); result.include(maxX, maxY, maxZ); return result;
	}
	private static function same(a:Matrix3D, b:Matrix3D, label:String):Void {
		for (i in 0...16) near(a.rawData[i], b.rawData[i], label);
	}
	private static function near(a:Float, b:Float, label:String):Void { check(Math.isFinite(a) && Math.abs(a - b) < 1e-6, label); }
	private static function check(value:Bool, label:String):Void { if (!value) throw "方向光阴影取景检查失败：" + label; }
}
