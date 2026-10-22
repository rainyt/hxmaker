package hx.render3d;

/** 场景级距离雾；距离为相机到片元的世界空间直线距离。 */
class FogSettings3D {
	public var enabled:Bool = false;
	public var mode:FogMode3D = FogMode3D.LINEAR;
	/** sRGB 显示颜色，进入着色器前转换为线性值。 */
	public var color:Int = 0xb8c8d8;
	public var start:Float = 10;
	/** 线性模式达到最大雾量的距离；指数模式不使用此值。 */
	public var end:Float = 100;
	/** 指数模式的密度，单位为世界距离的倒数；零表示没有雾。 */
	public var density:Float = 0.02;
	public var maxOpacity:Float = 1;
	/** 天空视为无限远；开启时按最大雾量混合，不影响 IBL 光照。 */
	public var affectSkybox:Bool = false;

	public function new() {}

	public function settingsKey():String {
		if (mode != FogMode3D.LINEAR && mode != FogMode3D.EXP && mode != FogMode3D.EXP2) throw "距离雾模式无效";
		for (value in [start, end, density, maxOpacity]) if (!Math3D.finite(value)) throw "距离雾参数必须有限";
		if (color < 0 || color > 0xffffff || start < 0 || start > 1e9 || end < 0 || end > 1e9
			|| (mode == FogMode3D.LINEAR && end <= start) || density < 0 || density > 1e6
			|| maxOpacity < 0 || maxOpacity > 1) throw "距离雾参数范围无效";
		var values:Array<Dynamic> = [enabled, mode, color, start, end, density, maxOpacity, affectSkybox];
		return values.join(":");
	}

	/** 返回业务预览使用的雾量，不改变颜色或资源。 */
	public function factorAt(distance:Float):Float {
		settingsKey();
		if (!Math3D.finite(distance) || distance < 0) throw "距离雾采样距离无效";
		if (!enabled) return 0;
		var delta = Math.max(0, distance - start);
		var amount = switch (mode) {
			case FogMode3D.LINEAR: Math.min(1, delta / (end - start));
			case FogMode3D.EXP: 1 - Math.exp(-delta * density);
			case FogMode3D.EXP2: 1 - Math.exp(-Math.pow(delta * density, 2));
			default: 0.;
		};
		return amount * maxOpacity;
	}

	public function skyboxFactor():Float {
		return enabled && affectSkybox && (mode == FogMode3D.LINEAR || density > 0) ? maxOpacity : 0;
	}

	public function getLinearColor():Array<Float> {
		return [for (shift in [16, 8, 0]) {
			var channel = ((color >> shift) & 255) / 255.;
			channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
		}];
	}

	/** 可供 Blender 导出器与场景资源使用；不依赖 Blender 或 glTF 类型。 */
	public function toData():Dynamic {
		settingsKey();
		return {format:"hxmaker-fog-1", enabled:enabled, mode:cast(mode, String), color:color,
			start:start, end:end, density:density, maxOpacity:maxOpacity, affectSkybox:affectSkybox};
	}

	public static function fromData(data:Dynamic):FogSettings3D {
		if (data == null || Reflect.field(data, "format") != "hxmaker-fog-1") throw "距离雾配置格式不支持";
		var result = new FogSettings3D();
		for (name in ["enabled", "affectSkybox"]) if (Reflect.hasField(data, name)) {
			var value = Reflect.field(data, name);
			if (!Std.isOfType(value, Bool)) throw "距离雾布尔参数无效：" + name;
			Reflect.setField(result, name, value);
		}
		if (Reflect.hasField(data, "mode")) {
			var value = Reflect.field(data, "mode");
			if (!Std.isOfType(value, String)) throw "距离雾模式必须为字符串";
			result.mode = value;
		}
		for (name in ["start", "end", "density", "maxOpacity", "color"]) if (Reflect.hasField(data, name)) {
			var value:Dynamic = Reflect.field(data, name);
			if ((!Std.isOfType(value, Int) && !Std.isOfType(value, Float)) || !Math3D.finite(value)) throw "距离雾数值参数无效：" + name;
			if (name == "color") {
				if (value < 0 || value > 0xffffff || value != Math.floor(value)) throw "距离雾颜色必须为 RGB 整数";
				result.color = Std.int(value);
			} else Reflect.setField(result, name, value);
		}
		result.settingsKey(); return result;
	}

	/** 完整校验后才替换现有参数，加载失败不会留下半份配置。 */
	public function setData(data:Dynamic):Void {
		var source = fromData(data);
		enabled = source.enabled; mode = source.mode; color = source.color; start = source.start; end = source.end;
		density = source.density; maxOpacity = source.maxOpacity; affectSkybox = source.affectSkybox;
	}
}
