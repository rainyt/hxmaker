package;

import hx.assets.Assets;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Label;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.light.Environment3D;
import hx.light.SkyEnvironment3D;
import hx.material.PbrMaterial3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.render3d.SkyboxTexture3D;

/** 高清天空、同源反射与跨视口资源共享示例。 */
class GameStage extends hx.display.Stage {
	public var scene(default, null):Scene3D;
	public var side(default, null):Scene3D;
	private var assets:Assets;
	private var resource:SkyboxTexture3D;
	private var sourceEnvironment:Environment3D;
	private var primary:SkyEnvironment3D;
	private var secondary:SkyEnvironment3D;
	private var control:OrbitCameraController3D;
	private var input:Scene3DInput;
	private var geometry:Geometry3D;
	private var materials:Array<PbrMaterial3D> = [];
	private var status:Label;
	#if hxmaker_skybox_checks
	private var checks:SkyboxChecks;
	#end

	override public function onStageInit():Void {
		super.onStageInit();
		scene = makeScene(24, 140, 650, 430);
		side = makeScene(694, 140, 242, 242);
		scene.autoRender = side.autoRender = false;
		control = new OrbitCameraController3D(scene.camera, new Vector3D());
		control.minPitch = -85; control.maxPitch = 85;
		input = new Scene3DInput(scene, control);
		geometry = BoxGeometry.create(1.5, 1.5, 1.5);
		for (i in 0...2) {
			var material = new PbrMaterial3D(null, i == 0 ? 0xe8c497 : 0x77bfff, i == 0 ? 1 : 0, 0.18);
			if (i == 1) { material.alphaMode = AlphaMode3D.BLEND; material.opacity = 0.45; material.depthWrite = false; material.cullMode = CullMode3D.NONE; }
			materials.push(material);
			var mesh = new MeshObject(geometry, material); mesh.x = i == 0 ? -1.1 : 1.1;
			scene.root.addChild(mesh);
		}
		label("天空环境：拖动主视口旋转，滚轮缩放；右侧为空场景，共享同一张天空图片", 24, 18, 19);
		action("天空开关", 24, () -> { if (primary != null) primary.skybox.enabled = !primary.skybox.enabled; });
		action("环境旋转 +30°", 170, () -> { if (primary != null) primary.rotation += 30; });
		action("IBL 开关", 370, () -> { if (primary != null) primary.environment.enabled = !primary.environment.enabled; });
		action("曝光切换", 520, () -> { if (primary != null) primary.skybox.exposure = primary.skybox.exposure == 1 ? 2 : 1; });
		action("Bloom 开关", 690, () -> scene.bloom.enabled = !scene.bloom.enabled);
		label("右侧参数独立；两个视口均关闭自动重绘", 694, 402, 13);
		status = label("正在加载天空资源", 24, 590, 15);
		addEventListener(Event.UPDATE, _ -> {
			control.update(hx.core.Hxmaker.engine.dt);
			status.data = "天空：" + scene.stats.skyboxStatus + "　天空批次：" + scene.stats.skyboxDrawCalls
				+ "　模型批次：" + scene.stats.drawCalls + "　纹理：" + Math.round(scene.stats.skyboxTextureBytes / 1024) + " KiB"
				+ "\n主视口重绘：" + scene.stats.redrawId + "　右侧重绘：" + side.stats.redrawId;
			#if hxmaker_skybox_checks
			if (checks != null) checks.update();
			#end
		});
		assets = new Assets(); assets.tryLoadTimes = 0;
		assets.loadBitmapData("assets/sky/sky.png"); assets.loadJson("assets/sky/sky.json");
		assets.loadBitmapData("assets/sky/environment.png"); assets.loadJson("assets/sky/environment.json");
		assets.onComplete(_ -> {
			if (isDisposed) { assets.clean(); return; }
			resource = SkyboxTexture3D.fromData(assets.getBitmapData("sky"), assets.getObject("sky"));
			sourceEnvironment = Environment3D.fromData(assets.getBitmapData("environment"), assets.getObject("environment"));
			primary = new SkyEnvironment3D(resource, sourceEnvironment); primary.skybox.toneMapping = true; primary.applyTo(scene);
			secondary = new SkyEnvironment3D(resource, sourceEnvironment); secondary.skybox.toneMapping = true; secondary.applyTo(side);
			#if hxmaker_skybox_checks
			checks = new SkyboxChecks(scene, side, primary, secondary, resource);
			#end
		});
		assets.onError(error -> { status.data = "天空加载失败：" + error.error; trace(status.data); });
		assets.start();
	}

	private function makeScene(x:Float, y:Float, width:Float, height:Float):Scene3D {
		var result = new Scene3D(width, height); result.x = x; result.y = y;
		result.backgroundColor = 0x172033; result.backgroundAlpha = 1; result.ambientIntensity = 0.1;
		var camera = new Camera3D(); result.root.addChild(camera); result.camera = camera;
		camera.lookFrom(new Vector3D(0, 1.5, 7), new Vector3D()); addChild(result); return result;
	}
	private function label(text:String, x:Float, y:Float, size:Int):Label {
		var value = new Label(text); value.x = x; value.y = y; value.fontSize = size; value.color = 0xe0ecff; addChild(value); return value;
	}
	private function action(text:String, x:Float, callback:Void->Void):Void {
		var value = label(text, x, 84, 18); value.color = 0x8ed6ff; value.mouseEnabled = true;
		value.addEventListener(MouseEvent.CLICK, _ -> callback());
	}
	override public function dispose():Void {
		if (isDisposed) return;
		#if hxmaker_skybox_checks
		if (checks != null) checks.dispose();
		#end
		if (input != null) input.dispose(); if (control != null) control.dispose();
		if (primary != null) primary.dispose(); if (secondary != null) secondary.dispose();
		super.dispose();
		if (sourceEnvironment != null) sourceEnvironment.dispose(); if (resource != null) resource.dispose();
		if (assets != null) assets.clean(); if (geometry != null) geometry.dispose();
		for (material in materials) material.dispose();
	}
}
