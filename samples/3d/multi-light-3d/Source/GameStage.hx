package;

import hx.core.Hxmaker;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Stage;
import hx.display.Label;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.light.Light3D;
import hx.light.PointLight3D;
import hx.light.SpotLight3D;
import hx.material.Material3D;
import hx.material.LambertTextureMaterial;
import hx.material.UnlitTextureMaterial;

/** 不依赖外部资产的多光源交互验收场景；检查仅在点击按钮后执行。 */
class GameStage extends Stage {
	private var scene:Scene3D;
	private var orbit:OrbitCameraController3D;
	private var cameraInput:Scene3DInput;
	private var sun:DirectionalLight3D;
	private var red:PointLight3D;
	private var blue:PointLight3D;
	private var spot:SpotLight3D;
	private var extra:PointLight3D;
	private var parentLight:Node3D;
	private var status:Label;
	private var controls:Array<Label> = [];
	private var markers:Array<MeshObject> = [];
	private var markerLights:Array<Light3D> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var moving:Bool = true;
	private var elapsed:Float = 0;

	override public function onStageInit():Void {
		super.onStageInit();
		label("点光 · 聚光 · 多光源", 24, 18, 27, 0xffffff);
		label("彩色点光混合 / 聚光软边 / 主方向光阴影 / 最多 4 灯", 24, 58, 17, 0xb6c7de);
		scene = new Scene3D(1052, 530); scene.x = 24; scene.y = 170;
		scene.backgroundColor = 0x101725; scene.backgroundAlpha = 1;
		scene.ambientIntensity = 0.045;
		addChild(scene);
		var camera = new Camera3D(); camera.setPosition(10, 9, 13); camera.lookAt(new Vector3D(0, 0.5, 0));
		scene.root.addChild(camera); scene.camera = camera;
		orbit = new OrbitCameraController3D(camera, new Vector3D(0, 0.5, 0));
		orbit.minDistance = 5; orbit.maxDistance = 40;
		orbit.minPitch = 5; orbit.maxPitch = 85;
		cameraInput = new Scene3DInput(scene, orbit);
		cameraAction("拉近镜头", 660, function() { orbit.zoomBy(0.8); });
		cameraAction("拉远镜头", 800, function() { orbit.zoomBy(1.25); });
		cameraAction("镜头复位", 940, resetCamera);
		label("拖动环绕 · 滚轮缩放 · 单指拖动", 730, 58, 15, 0xb6c7de);
		sun = new DirectionalLight3D(0xffffff, 0.35); sun.shadowEnabled = true;
		scene.root.addChild(sun); scene.light = sun;
		red = new PointLight3D(0xff3020, 3, 8); red.setPosition(-3, 2, 1);
		scene.root.addChild(red); scene.addLight(red);
		parentLight = new Node3D(); scene.root.addChild(parentLight);
		blue = new PointLight3D(0x3080ff, 3, 8); blue.setPosition(3, 2, 1);
		parentLight.addChild(blue); scene.addLight(blue);
		spot = new SpotLight3D(0xffe7a0, 4, 12); spot.setPosition(0, 6, -2);
		spot.direction = new Vector3D(0, -1, 0.25); scene.root.addChild(spot); scene.addLight(spot);
		extra = new PointLight3D(0x30ff60, 3, 9); extra.setPosition(0, 2, 4); extra.visible = false;
		scene.root.addChild(extra); scene.addLight(extra);
		mesh(PlaneGeometry.create(18, 16), new LambertTextureMaterial(null, 0xb0b0b0), 0, 0, 0);
		for (x in -2...3) for (z in -1...2) {
			var box = mesh(BoxGeometry.create(1.15, 1.5, 1.15), new LambertTextureMaterial(null, 0xc8c8c8), x * 2.3, 0.75, z * 2.5);
			box.castShadow = true;
		}
		for (light in [cast(red, Light3D), cast(blue, Light3D), cast(spot, Light3D), cast(extra, Light3D)]) {
			markerLights.push(light);
			markers.push(mesh(BoxGeometry.create(0.18, 0.18, 0.18), new UnlitTextureMaterial(null, light.color), 0, 0, 0));
		}
		action(24, 94, function() { sun.visible = !sun.visible; });
		action(205, 94, function() { red.visible = !red.visible; });
		action(386, 94, function() { blue.visible = !blue.visible; });
		action(567, 94, function() { spot.visible = !spot.visible; });
		action(748, 94, function() { moving = !moving; });
		action(24, 130, function() { spot.outerAngle = spot.outerAngle == 30 ? 48 : 30; });
		action(205, 130, function() { red.range = red.range == 8 ? 4 : 8; blue.range = red.range; });
		action(386, 130, function() { sun.shadowEnabled = !sun.shadowEnabled; });
		action(567, 130, function() { extra.visible = !extra.visible; });
		action(748, 130, function() { parentLight.visible = !parentLight.visible; });
		action(925, 94, function() { scene.autoRender = !scene.autoRender; });
		var checkButton = label("运行参数检查", 925, 130, 17, 0x8ed6ff);
		checkButton.addEventListener(MouseEvent.CLICK, function(_) {
			try { LightingChecks.run(); checkButton.data = "参数检查通过"; }
			catch (error:Dynamic) { checkButton.data = "检查失败：" + Std.string(error); }
		});
		status = label("等待首次绘制", 24, 717, 16, 0xb6c7de);
		scene.addEventListener(Event.UPDATE, function(_) {
			var dt = Hxmaker.engine.dt;
			orbit.update(dt);
			updateLights(dt);
		});
		updateLights(0);
	}

	private function updateLights(dt:Float):Void {
		if (moving) {
			elapsed += dt;
			red.setPosition(-3 + Math.sin(elapsed) * 1.7, 2, 1 + Math.cos(elapsed) * 2);
			parentLight.rotationY = Math.sin(elapsed * 0.5) * 35;
			spot.direction = new Vector3D(Math.sin(elapsed * 0.7) * 0.35, -1, 0.25);
		}
		for (i in 0...markers.length) {
			var light = markerLights[i], m = light.getWorldMatrix().rawData;
			markers[i].setPosition(m[12], m[13], m[14]); markers[i].visible = light.isWorldVisible();
		}
		var titles = ["方向光：" + state(sun.visible), "红点光：" + state(red.visible), "蓝点光：" + state(blue.visible),
			"聚光：" + state(spot.visible), "移动：" + state(moving), "外锥半角：" + spot.outerAngle,
			"点光范围：" + red.range, "主光阴影：" + state(sun.shadowEnabled), "第五灯：" + state(extra.visible), "蓝光父节点：" + state(parentLight.visible), "自动重绘：" + state(scene.autoRender)];
		for (i in 0...controls.length) controls[i].data = titles[i];
		status.data = "参与灯光：" + scene.stats.activeLights + "　超限跳过：" + scene.stats.skippedLights
			+ "　绘制批次：" + scene.stats.drawCalls + "　阴影：" + scene.stats.shadowStatus;
	}

	/** 复位同时结束拖动，避免残余输入改变恢复后的镜头。 */
	private function resetCamera():Void {
		cameraInput.cancel("cameraReset");
		orbit.target.setTo(0, 0.5, 0);
		scene.camera.setPosition(10, 9, 13);
		orbit.syncFromCamera();
		orbit.snap();
	}

	private function cameraAction(text:String, x:Float, callback:Void->Void):Void {
		var result = label(text, x, 24, 18, 0x8ed6ff);
		result.mouseEnabled = true;
		result.addEventListener(MouseEvent.CLICK, function(_) { callback(); });
	}

	private function state(value:Bool):String { return value ? "开启" : "关闭"; }
	private function action(x:Float, y:Float, callback:Void->Void):Void {
		var result = label("", x, y, 17, 0x8ed6ff); controls.push(result);
		result.addEventListener(MouseEvent.CLICK, function(_) { callback(); updateLights(0); });
	}
	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color;
		addChild(result); return result;
	}
	private function mesh(geometry:Geometry3D, material:Material3D, x:Float, y:Float, z:Float):MeshObject {
		geometries.push(geometry); materials.push(material);
		var result = new MeshObject(geometry, material); result.setPosition(x, y, z); scene.root.addChild(result); return result;
	}
	override public function dispose():Void {
		if (isDisposed) return;
		if (cameraInput != null) cameraInput.dispose();
		if (orbit != null) orbit.dispose();
		super.dispose();
		for (geometry in geometries) geometry.dispose();
		for (material in materials) material.dispose();
		geometries = []; materials = [];
	}
}
