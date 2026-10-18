import hx.render3d.FogMode3D;
import hx.render3d.FogSettings3D;

/** 配置边界与 Blender JSON 契约检查，不依赖渲染后端。 */
class FogSettingsChecks {
	static function main():Void {
		var fog = new FogSettings3D(); fog.enabled = true; fog.start = 10; fog.end = 30;
		check(fog.factorAt(0) == 0 && fog.factorAt(10) == 0 && fog.factorAt(30) == 1, "线性边界");
		fog.maxOpacity = 0.6; near(fog.factorAt(20), 0.3, "最大雾量缩放");
		fog.mode = FogMode3D.EXP; fog.density = 0.1; near(fog.factorAt(20), (1-Math.exp(-1))*0.6, "指数雾");
		fog.mode = FogMode3D.EXP2; near(fog.factorAt(30), (1-Math.exp(-4))*0.6, "平方指数雾");
		fog.affectSkybox = true; fog.density = 0; check(fog.skyboxFactor() == 0, "零密度不影响天空");
		fog.density = 0.1; fog.color = 0x80ffff;
		var copy = FogSettings3D.fromData(haxe.Json.parse(haxe.Json.stringify(fog.toData())));
		check(copy.settingsKey() == fog.settingsKey(), "场景配置往返");
		var before = fog.settingsKey(), failed = false;
		try { fog.setData({format:"hxmaker-fog-1", mode:"linear", start:20., end:10.}); } catch (_:Dynamic) { failed = true; }
		check(failed && fog.settingsKey() == before, "无效加载保持原配置");
		var invalid:Array<Dynamic> = [{format:"hxmaker-fog-1", enabled:"true"}, {format:"hxmaker-fog-1", mode:"unknown"},
			{format:"hxmaker-fog-1", density:-1}, {format:"hxmaker-fog-1", maxOpacity:1.1},
			{format:"hxmaker-fog-1", color:1.5}, {format:"hxmaker-fog-1", color:16777216},
			{format:"hxmaker-fog-1", start:Math.NaN}, {format:"unknown"}];
		for (data in invalid) {
			failed = false; try { FogSettings3D.fromData(data); } catch (_:Dynamic) { failed = true; }
			check(failed, "拒绝无效场景配置");
		}
		near(copy.getLinearColor()[0], 0.2158605001, "sRGB 颜色解码");
		trace("HXMAKER_FOG_SETTINGS PASS");
	}
	static function check(value:Bool, label:String):Void { if (!value) throw "距离雾检查失败：" + label; }
	static function near(actual:Float, expected:Float, label:String):Void { check(Math.abs(actual-expected) < 1e-8, label); }
}
