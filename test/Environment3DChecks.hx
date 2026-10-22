import hx.core.OpenFlBitmapData;
import hx.display.Scene3D;
import hx.light.Environment3D;

/** 环境图集接入、跨场景共享与生命周期检查；准备手动入口，本次不执行。 */
class Environment3DChecks {
	public static function run():Void {
		var bitmap = OpenFlBitmapData.fromSize(66, 236, false, 0x808080);
		var metadata:Dynamic = {format:"hxmaker-ibl-1", encoding:"linear-rgb-range", layerWidth:64, layerHeight:32, levels:4, radianceRange:8.};
		var environment = Environment3D.fromData(bitmap, metadata);
		var a = new Scene3D(), b = new Scene3D();
		a.environment = environment; b.environment = environment;
		try {
			var originalA = a.lightingKey(), originalB = b.lightingKey();
			environment.rotation = 45;
			check(a.lightingKey() != originalA && b.lightingKey() != originalB, "共享环境旋转使两个场景设置键失效");
			var rotated = a.lightingKey(); environment.enabled = false;
			check(a.lightingKey() != rotated, "关闭环境改变重绘检测键");
			var disabled = a.lightingKey(); environment.intensity = 0.5;
			check(a.lightingKey() != disabled, "环境强度改变重绘检测键");
			var previous = a.lightingKey(); environment.invalidate();
			check(a.lightingKey() != previous, "图集内容显式失效传播到场景");
			a.dispose();
			check(!environment.isDisposed && b.environment == environment, "销毁一个场景不销毁共享环境");
			b.environment = null; environment.dispose();
			check(bitmap.width == 66 && bitmap.height == 236, "销毁环境不销毁借用图片");
			var rejected = false;
			try {
				Environment3D.fromData(bitmap, {format:"hxmaker-ibl-1", encoding:"linear-rgb-range", layerWidth:64, layerHeight:32, levels:5, radianceRange:8.});
			} catch (_:Dynamic) { rejected = true; }
			check(rejected, "布局不匹配的环境图集不能接入");
		} catch (error:Dynamic) {
			a.dispose(); b.dispose(); environment.dispose(); bitmap.data.dispose(); throw error;
		}
		a.dispose(); b.dispose(); environment.dispose(); bitmap.data.dispose();
		trace("HXMAKER_ENVIRONMENT_3D_CHECKS PASS");
	}
	private static function check(value:Bool, label:String):Void {
		if (!value) throw "IBL 检查失败：" + label;
	}
}
