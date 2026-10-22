package hx.light;

import hx.display.Scene3D;
import hx.render3d.Math3D;
import hx.render3d.Skybox3D;
import hx.render3d.SkyboxTexture3D;

/** 单场景天空与 IBL 联动配置；复制环境参数，资源继续共享。 */
class SkyEnvironment3D {
	public var skybox(default, null):Skybox3D;
	public var environment(default, null):Environment3D;
	public var rotation(get, set):Float;
	public var isDisposed(default, null):Bool = false;
	private var scene:Scene3D;
	private var angle:Float = 0;

	public function new(texture:SkyboxTexture3D, source:Environment3D = null) {
		skybox = new Skybox3D(texture);
		if (source != null) {
			source.settingsKey();
			environment = new Environment3D(source.atlas, source.layerWidth, source.layerHeight, source.levels, source.radianceRange);
			environment.intensity = source.intensity; environment.enabled = source.enabled;
			rotation = source.rotation;
		}
	}
	private function get_rotation():Float { return angle; }
	private function set_rotation(value:Float):Float {
		if (isDisposed || !Math3D.finite(value)) throw "天空环境旋转无效";
		angle = value; skybox.rotation = value;
		if (environment != null) environment.rotation = value;
		return value;
	}
	/** 同一配置只绑定一个场景；多个场景分别创建配置即可共享图片。 */
	public function applyTo(value:Scene3D):Void {
		if (isDisposed || value == null || value.isDisposed) throw "天空环境或场景已经释放";
		skybox.settingsKey(); if (environment != null) environment.settingsKey();
		detach(); scene = value; value.skybox = skybox; value.environment = environment; value.requestRender();
	}
	public function detach():Void {
		if (scene == null) return;
		if (scene.skybox == skybox) scene.skybox = null;
		if (scene.environment == environment) scene.environment = null;
		scene.requestRender(); scene = null;
	}
	/** 解除绑定并销毁本配置，不释放源环境或共享图片。 */
	public function dispose():Void {
		if (isDisposed) return;
		detach(); isDisposed = true; skybox.dispose();
		if (environment != null) environment.dispose();
	}
}
