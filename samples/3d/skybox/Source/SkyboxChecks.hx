package;

#if hxmaker_skybox_checks
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.geom.Vector3D;
import hx.light.SkyEnvironment3D;
import hx.render3d.SkyboxTexture3D;
import hx.render3d.Skybox3D;
import hx.render3d.openfl.Renderer3D;
import hx.render3d.openfl.Scene3DDisplay;
import lime.utils.UInt8Array;

/** 仅验收构建启用的断言和 GPU 读回入口。 */
@:access(hx.core.Render)
@:access(hx.render3d.openfl.Scene3DDisplay)
@:access(hx.render3d.openfl.Renderer3D)
class SkyboxChecks {
	private var main:Scene3D;
	private var side:Scene3D;
	private var primary:SkyEnvironment3D;
	private var secondary:SkyEnvironment3D;
	private var resource:SkyboxTexture3D;
	private var camera:Camera3D;
	private var fixture:SkyboxTexture3D;
	private var fixtureConfig:Skybox3D;
	private var preview:SkyboxTexture3D;
	private var previewConfig:Skybox3D;
	private var announced:Bool = false;
	private var savedPrecision:Bool = true;
	private var savedTextureLimit:Int = 0;

	public function new(main:Scene3D, side:Scene3D, primary:SkyEnvironment3D, secondary:SkyEnvironment3D, resource:SkyboxTexture3D) {
		this.main = main; this.side = side; this.primary = primary; this.secondary = secondary; this.resource = resource; camera = side.camera;
		coreChecks();
		var width = 30, height = 15;
		var bitmap = new openfl.display.BitmapData(width, height, false, 0);
		for (y in 0...height) for (x in 0...width) {
			var theta = (y + 0.5) / height * Math.PI, phi = ((x + 0.5) / width - 0.5) * Math.PI * 2;
			var r = Math.round((Math.sin(theta) * Math.cos(phi) + 1) * 127.5);
			var g = Math.round((Math.cos(theta) + 1) * 127.5);
			var b = Math.round((Math.sin(theta) * Math.sin(phi) + 1) * 127.5);
			bitmap.setPixel(x, y, (r << 16) | (g << 8) | b);
		}
		fixture = SkyboxTexture3D.fromPanorama(OpenFlBitmapData.fromBitmapData(bitmap)); fixtureConfig = new Skybox3D(fixture);
		preview = SkyboxTexture3D.fromEnvironment(secondary.environment); previewConfig = new Skybox3D(preview); previewConfig.toneMapping = true;
		Reflect.setField(js.Browser.window, "__hxmakerSkybox", {state:state, command:command, pixel:pixel});
	}

	private function coreChecks():Void {
		var key = main.skyboxKey(); primary.rotation = 30;
		check(main.skyboxKey() != key && primary.environment.rotation == 30, "联动旋转使天空和 IBL 同步失效");
		check(secondary.rotation == 0 && secondary.skybox.rotation == 0 && secondary.environment.rotation == 0, "共享图片的参数互不影响");
		primary.rotation = 0; key = side.skyboxKey(); resource.invalidate();
		check(side.skyboxKey() != key, "共享资源版本传播");
		var old = resource.version;
		var copy = new Scene3D(); copy.skybox = new Skybox3D(resource); copy.dispose();
		check(!resource.isDisposed && resource.version == old, "场景销毁不释放借用资源");
		var low = SkyboxTexture3D.fromEnvironment(primary.environment);
		check(low.offset == 1 && low.width == primary.environment.layerWidth, "旧 IBL 第零层复用"); low.dispose();
		var rejected = false;
		try { SkyboxTexture3D.fromData(resource.bitmap, {format:"hxmaker-sky-1", encoding:"sRGB", width:512, height:256, radianceRange:1}); }
		catch (_:Dynamic) { rejected = true; }
		check(rejected, "拒绝错误编码");
		primary.skybox.exposure = Math.NaN; rejected = false;
		try { primary.skybox.settingsKey(); } catch (_:Dynamic) { rejected = true; }
		check(rejected, "拒绝非有限参数"); primary.skybox.exposure = 1;
		trace("HXMAKER_SKYBOX_CORE PASS");
	}

	public function update():Void {
		if (!announced && side.stats.skyboxDrawCalls == 1 && main.stats.skyboxDrawCalls == 1) {
			announced = true; trace("HXMAKER_SKYBOX_READY PASS");
		}
	}
	private function renderer(scene:Scene3D):Renderer3D {
		var render:hx.core.Render = cast Hxmaker.engine.renderer;
		var display = render.__scene3DDisplays.get(scene);
		return display == null ? null : display.renderer3D;
	}
	private function state():Dynamic {
		var render = renderer(side);
		return {main:main.stats, side:side.stats, version:side.contentVersion,
			rotation:primary.environment.rotation, sideRotation:secondary.environment.rotation,
			webglVersion:render == null || render.gl == null || render.gl.isContextLost() ? "" : Std.string(render.gl.getParameter(render.gl.VERSION)),
			glError:render == null || render.gl == null || render.gl.isContextLost() ? -1 : render.gl.getError()};
	}
	/** 从三维离屏目标读回，避免二维平台合成差异掩盖天空通道结果。 */
	private function pixel(x:Float = 0.5, y:Float = 0.5, mainView:Bool = false):Array<Int> {
		var render = renderer(mainView ? main : side);
		if (render == null || render.target == null || render.gl == null || render.gl.isContextLost()) return [];
		var gl = render.gl, previous:Dynamic = gl.getParameter(gl.FRAMEBUFFER_BINDING), result = new UInt8Array(4);
		gl.bindFramebuffer(gl.FRAMEBUFFER, render.target.framebuffer);
		gl.readPixels(Std.int(x * (render.target.width - 1)), Std.int(y * (render.target.height - 1)), 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, result);
		gl.bindFramebuffer(gl.FRAMEBUFFER, previous);
		return [for (i in 0...4) result[i]];
	}
	private function command(name:String):Void {
		switch (name) {
			case "rotate": side.skybox.rotation += 90;
			case "translate": camera.x += 100; camera.y += 40; camera.z -= 20;
			case "exposure": side.skybox.exposure = 2;
			case "mainDisable": primary.skybox.enabled = false;
			case "mainEnable": primary.skybox.enabled = true;
			case "disable": side.skybox.enabled = false;
			case "enable": side.skybox.enabled = true;
			case "invalidate": side.skybox.texture.invalidate();
			case "bloom": main.bloom.enabled = !main.bloom.enabled;
			case "clip": camera.near = 0.01; camera.far = 0.02;
			case "fov": camera.fieldOfView = 100;
			case "noCamera": side.camera = null;
			case "restoreCamera": side.camera = camera;
			case "fixture": side.skybox = fixtureConfig; camera.lookFrom(new Vector3D(), new Vector3D(1, 0, 0));
			case "negativeX": camera.lookFrom(new Vector3D(), new Vector3D(-1, 0, 0));
			case "seamLeft": camera.lookFrom(new Vector3D(), new Vector3D(-1, 0, 0.0001));
			case "seamRight": camera.lookFrom(new Vector3D(), new Vector3D(-1, 0, -0.0001));
			case "positiveZ": camera.lookFrom(new Vector3D(), new Vector3D(0, 0, 1));
			case "negativeZ": camera.lookFrom(new Vector3D(), new Vector3D(0, 0, -1));
			case "positiveY": camera.lookFrom(new Vector3D(), new Vector3D(0, 1, 0), new Vector3D(0, 0, 1));
			case "negativeY": camera.lookFrom(new Vector3D(), new Vector3D(0, -1, 0), new Vector3D(0, 0, 1));
			case "original": side.skybox = secondary.skybox; camera.near = 0.1; camera.far = 1000;
				camera.fieldOfView = 60; camera.lookFrom(new Vector3D(0, 1.5, 7), new Vector3D());
			case "ibl": side.skybox = previewConfig;
			case "loseContext":
				var render = renderer(side), extension:Dynamic = render.gl.getExtension("WEBGL_lose_context");
				if (extension == null) throw "缺少上下文丢失扩展";
				extension.loseContext(); haxe.Timer.delay(() -> extension.restoreContext(), 500);
			case "lowPrecision":
				var render = renderer(side); savedPrecision = render.fragmentDepthPrecision;
				if (render.skyboxPass != null) render.skyboxPass.dispose(); render.skyboxPass = null;
				render.fragmentDepthPrecision = false; side.requestRender();
			case "bright": side.skybox.exposure = 1000000;
			case "fullPrecision":
				var render = renderer(side);
				if (render.skyboxPass != null) render.skyboxPass.dispose(); render.skyboxPass = null;
				render.fragmentDepthPrecision = savedPrecision; side.skybox.exposure = 1; side.requestRender();
			case "limitSize":
				var render = renderer(side); savedTextureLimit = render.maxTextureSize; render.maxTextureSize = 8; side.requestRender();
			case "restoreSize": renderer(side).maxTextureSize = savedTextureLimit; side.requestRender();
			case "detachPrimary": primary.dispose();
			default: throw "未知天空验收命令：" + name;
		}
	}
	private static function check(value:Bool, message:String):Void { if (!value) throw "天空检查失败：" + message; }
	public function dispose():Void {
		Reflect.deleteField(js.Browser.window, "__hxmakerSkybox");
		fixtureConfig.dispose(); fixture.bitmap.data.dispose(); fixture.dispose(); previewConfig.dispose(); preview.dispose();
	}
}
#end
