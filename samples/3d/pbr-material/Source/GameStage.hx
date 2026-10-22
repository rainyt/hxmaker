package;

import hx.display.FPS;
import hx.display.BitmapData;
import hx.display3d.Model3D;
import hx.assets.Assets;
import hx.light.Environment3D;
import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.core.Hxmaker;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Label;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.geom.Vector3D;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.light.ShadowQuality3D;
import hx.material.Material3D;
import hx.material.LambertTextureMaterial;
import hx.material.PbrMaterial3D;

/** 材质与预积分环境光对比，支持手动镜头与自动环绕。 */
class GameStage extends hx.display.Stage {
	private var scene:Scene3D;
	private var camera:Camera3D;
	private var cameraControl:OrbitCameraController3D;
	private var cameraInput:Scene3DInput;
	private var autoControl:Label;
	private var description:Label;
	private var status:Label;
	private var environment:Environment3D;
	private var environmentAssets:Assets;
	private var environmentControl:Label;
	private var texturedModel:Model3D;
	private var modelAssets:Assets;
	private var modelControl:Label;
	private var texturedMode:Bool = false;
	private var unifiedPbr:Bool = false;
	private var pbrMeshes:Array<MeshObject> = [];
	private var mapControls:Array<Label> = [];
	private var mapsEnabled:Array<Bool> = [true, true, true, true];
	private var mappedMaterials:Array<{material:PbrMaterial3D, mr:BitmapData, normal:BitmapData, ao:BitmapData, emission:BitmapData, emissiveFactor:Array<Float>}> = [];
	private var autoOrbit:Bool = true;
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var originalPbrParameters:Array<{material:PbrMaterial3D, metallic:Float, roughness:Float}> = [];

	override public function onStageInit():Void {
		super.onStageInit();
		var fps = new FPS();
		topView.addChild(fps);
		fps.scale = 0.5;
		fps.layoutData = new AnchorLayoutData(null, 0);
		topView.layout = new AnchorLayout();

		scene = new Scene3D(912, 370);
		scene.x = 24;
		scene.y = 205;
		scene.backgroundColor = 0x172033;
		scene.backgroundAlpha = 1;
		scene.ambientIntensity = 0.3;
		addChild(scene);
		camera = new Camera3D();
		camera.near = 0.5;
		camera.setPosition(0, 4.5, 11);
		scene.root.addChild(camera);
		scene.camera = camera;
		camera.lookAt(new Vector3D(0, 0.3, 0));
		cameraControl = new OrbitCameraController3D(camera, new Vector3D(0, 0.3, 0));
		cameraControl.minDistance = 4;
		cameraControl.maxDistance = 30;
		cameraControl.minPitch = 5;
		cameraControl.maxPitch = 80;
		cameraInput = new Scene3DInput(scene, cameraControl);
		cameraInput.addEventListener(Scene3DInputEvent.DRAG_BEGIN, _ -> {
			setAutoOrbit(false);
		});
		scene.addEventListener(MouseEvent.MOUSE_WHEEL, function(event:MouseEvent) {
			if (event.target == scene && !event.isDefaultPrevented && Math.isFinite(event.delta) && event.delta != 0)
				setAutoOrbit(false);
		});
		var keyLight = new DirectionalLight3D(0xffebd6, 3);
		keyLight.direction = new Vector3D(-0.5, -1, -0.8);
		keyLight.shadowEnabled = true;
		// 可选高质量档；范围、级联、过滤和偏差由引擎解析，无需手写世界包围盒。
		keyLight.shadowQuality = ShadowQuality3D.HIGH;
		scene.root.addChild(keyLight);
		scene.light = keyLight;
		var fillLight = new DirectionalLight3D(0xa9cfff, 1.2);
		fillLight.direction = new Vector3D(1, -0.3, 0.5);
		scene.root.addChild(fillLight);
		scene.addLight(fillLight);
		var sphere = createSphere();
		geometries.push(sphere);
		var roughness = [0.12, 0.3, 0.5, 0.7, 0.9];
		for (row in 0...3)
			for (column in 0...5) {
				var material:Material3D = row == 0 ? new LambertTextureMaterial(null,
					0xe4aa63) : new PbrMaterial3D(null, 0xe4aa63, row == 2 ? 1 : 0, roughness[column]);
				materials.push(material);
				if (row > 0) {
					var pbr:PbrMaterial3D = cast material;
					originalPbrParameters.push({material:pbr, metallic:pbr.metallic, roughness:pbr.roughness});
				}
				var mesh = new MeshObject(sphere, material);
				mesh.setPosition((column - 2) * 1.65, 0.7, (row - 1) * 2.1);
				mesh.castShadow = true;
				if (row > 0) pbrMeshes.push(mesh);
				scene.root.addChild(mesh);
			}
		var floorGeometry = PlaneGeometry.create(11, 9);
		geometries.push(floorGeometry);
		var floorMaterial = new LambertTextureMaterial(null, 0x47566d);
		materials.push(floorMaterial);
		scene.root.addChild(new MeshObject(floorGeometry, floorMaterial));
		var title = new Label("PBR 材质对比：拖动旋转 · 滚轮缩放 · 单指拖动");
		title.fontSize = 22;
		title.color = 0xffffff;
		title.x = 24;
		title.y = 18;
		addChild(title);
		description = new Label("初始视角由远到近：Lambert／PBR 非金属／PBR 金属；从左到右粗糙度 0.12 → 0.9");
		description.fontSize = 16;
		description.color = 0xd7e3fc;
		description.x = 24;
		description.y = 50;
		addChild(description);
		cameraAction("拉近镜头", 24, function() {
			setAutoOrbit(false);
			cameraControl.zoomBy(0.8);
		});
		cameraAction("拉远镜头", 150, function() {
			setAutoOrbit(false);
			cameraControl.zoomBy(1.25);
		});
		cameraAction("镜头复位", 276, resetCamera);
		autoControl = cameraAction("自动环绕：开启", 420, function() {
			cameraInput.cancel("cameraModeChanged");
			setAutoOrbit(!autoOrbit);
		});
		cameraAction("统一 PBR 参数", 610, function() { setUniformPbrParameters(true); });
		cameraAction("恢复原始参数", 790, function() { setUniformPbrParameters(false); });
		environmentControl = cameraAction("环境光：加载中", 24, function() {
			if (environment == null) return;
			environment.enabled = !environment.enabled;
			updateEnvironmentControl();
		}, 128);
		cameraAction("降低环境亮度", 220, function() {
			if (environment != null) environment.intensity = Math.max(0.05, environment.intensity / 1.25);
		}, 128);
		cameraAction("提高环境亮度", 410, function() {
			if (environment != null) environment.intensity = Math.min(4, environment.intensity * 1.25);
		}, 128);
		cameraAction("旋转环境 30°", 600, function() {
			if (environment != null) environment.rotation = (environment.rotation + 30) % 360;
		}, 128);
		cameraAction("环境复位", 790, function() {
			if (environment == null) return;
			environment.enabled = true; environment.intensity = 1; environment.rotation = 0;
			updateEnvironmentControl();
		}, 128);
		modelControl = cameraAction("贴图示例：加载中", 24, function() { showTexturedModel(!texturedMode); }, 168);
		var mapTitles = ["金属粗糙", "法线", "AO", "自发光"];
		for (i in 0...4) {
			var index = i;
			mapControls.push(cameraAction(mapTitles[i] + "：开启", 220 + i * 190, function() {
				mapsEnabled[index] = !mapsEnabled[index];
				applyMapSettings();
			}, 168));
		}
		status = new Label("等待首帧绘制");
		status.fontSize = 14;
		status.color = 0xd7e3fc;
		status.x = 24;
		status.y = 594;
		addChild(status);
		scene.addEventListener(Event.UPDATE, _ -> {
			var dt = Hxmaker.engine.dt;
			// 两种模式都通过同一控制器推进，切换时保留当前观察角度与距离。
			if (autoOrbit && !cameraInput.capturing)
				cameraControl.rotate(dt * 8, 0);
			cameraControl.update(dt);
			status.data = "主场景批次：" + scene.stats.drawCalls + "　阴影批次：" + scene.stats.shadowDrawCalls
				+ "　合成批次：" + scene.stats.compositeDrawCalls + "　环境：" + scene.stats.environmentStatus
				+ (environment == null ? "" : "　" + Math.round(environment.intensity * 100) / 100 + " 倍 / " + environment.rotation + "°")
				+ "\n阴影：" + scene.stats.shadowFitMode + "　每级：" + scene.stats.shadowMapSize + "　级联：" + scene.stats.shadowCascades
				+ "　世界纹素：" + scene.stats.shadowWorldTexels.map(value -> Math.round(value * 10000) / 10000).join(" / ");
		});
		loadEnvironment();
		loadTexturedModel();
	}

	/** 加载内嵌五种贴图与显式切线的 GLB，保持原有球阵列作为独立对照。 */
	private function loadTexturedModel():Void {
		var assets = new Assets(); modelAssets = assets; assets.tryLoadTimes = 0;
		assets.loadModel("assets/pbr/material-sphere.glb");
		assets.onComplete(_ -> {
			if (isDisposed) { assets.clean(); return; }
			try {
				texturedModel = assets.getModel("material-sphere").createInstance(-1, {pbrEnabled:true});
				texturedModel.visible = false;
				scene.root.addChild(texturedModel);
				var seen:Array<PbrMaterial3D> = [];
				for (mesh in texturedModel.meshes) {
					mesh.castShadow = true;
					var material:PbrMaterial3D = cast mesh.material;
					if (seen.indexOf(material) >= 0) continue;
					seen.push(material);
					mappedMaterials.push({material:material, mr:material.metallicRoughnessTexture, normal:material.normalTexture,
						ao:material.occlusionTexture, emission:material.emissiveTexture, emissiveFactor:material.emissive});
				}
				modelControl.data = "贴图示例：关闭";
				applyMapSettings();
			} catch (error:Dynamic) {
				modelControl.data = "贴图示例：数据无效";
				trace("PBR 贴图模型加载失败：" + Std.string(error));
			}
		});
		assets.onError(error -> {
			if (isDisposed) { assets.clean(); return; }
			modelControl.data = "贴图示例：加载失败";
			trace("PBR 贴图模型加载失败：" + error.error);
		});
		assets.start();
	}

	private function applyMapSettings():Void {
		for (original in mappedMaterials) {
			original.material.metallicRoughnessTexture = mapsEnabled[0] ? original.mr : null;
			original.material.normalTexture = mapsEnabled[1] ? original.normal : null;
			original.material.occlusionTexture = mapsEnabled[2] ? original.ao : null;
			original.material.emissiveTexture = mapsEnabled[3] ? original.emission : null;
			// 示例关闭自发光时同时清零因子，避免无贴图回退为整球恒定发光。
			original.material.emissive = mapsEnabled[3] ? original.emissiveFactor : [0., 0., 0.];
		}
		var titles = ["金属粗糙", "法线", "AO", "自发光"];
		for (i in 0...mapControls.length) mapControls[i].data = titles[i] + "：" + (mapsEnabled[i] ? "开启" : "关闭");
		scene.requestRender();
	}

	private function showTexturedModel(value:Bool):Void {
		if (texturedModel == null) return;
		setAutoOrbit(false); texturedMode = value;
		texturedModel.visible = value;
		for (mesh in pbrMeshes) mesh.visible = !value;
		modelControl.data = "贴图示例：" + (value ? "开启" : "关闭");
		updateDescription();
		scene.requestRender();
	}

	private function updateDescription():Void {
		description.data = texturedMode ? "GLB 贴图球：棋盘基础色、金属粗糙度渐变、波纹法线、AO 网格与发光条纹"
			: unifiedPbr ? "统一 PBR：10 个球均为非金属，粗糙度 0.5；Lambert 球与地面保持原样"
			: "初始视角由远到近：Lambert／PBR 非金属／PBR 金属；从左到右粗糙度 0.12 → 0.9";
	}

	/** 仅加载离线生成的自有摄影棚图集，不在首帧或每帧运行卷积。 */
	private function loadEnvironment():Void {
		var assets = new Assets(); environmentAssets = assets; assets.tryLoadTimes = 0;
		assets.loadBitmapData("assets/ibl/environment.png");
		assets.loadJson("assets/ibl/environment.json");
		assets.onComplete(_ -> {
			if (isDisposed) { assets.clean(); return; }
			try {
				environment = Environment3D.fromData(assets.getBitmapData("environment"), assets.getObject("environment"));
				scene.environment = environment;
				updateEnvironmentControl();
			} catch (error:Dynamic) {
				environmentControl.data = "环境光：数据无效";
				trace("IBL 数据加载失败：" + Std.string(error));
			}
		});
		assets.onError(error -> {
			if (isDisposed) { assets.clean(); return; }
			environmentControl.data = "环境光：加载失败";
			trace("IBL 图片或元数据加载失败：" + error.error);
		});
		assets.start();
	}

	private function updateEnvironmentControl():Void {
		environmentControl.data = "环境光：" + (environment.enabled ? "开启" : "关闭");
		scene.requestRender();
	}

	/** 保留各球独立材质，只切换参数，便于观察参数兼容时的自动合批。 */
	private function setUniformPbrParameters(unified:Bool):Void {
		setAutoOrbit(false);
		unifiedPbr = unified;
		showTexturedModel(false);
		for (original in originalPbrParameters) {
			original.material.metallic = unified ? 0 : original.metallic;
			original.material.roughness = unified ? 0.5 : original.roughness;
		}
		updateDescription();
		scene.requestRender();
	}

	private function setAutoOrbit(value:Bool):Void {
		autoOrbit = value;
		if (autoControl != null)
			autoControl.data = "自动环绕：" + (value ? "开启" : "关闭");
	}

	/** 复位先解除指针捕获，再对齐控制器，避免旧拖动和阻尼覆盖复位结果。 */
	private function resetCamera():Void {
		cameraInput.cancel("cameraReset");
		setAutoOrbit(false);
		cameraControl.target.setTo(0, 0.3, 0);
		camera.setPosition(0, 4.5, 11);
		cameraControl.syncFromCamera();
		cameraControl.snap();
	}

	private function cameraAction(text:String, x:Float, callback:Void->Void, y:Float = 88):Label {
		var result = new Label(text);
		result.fontSize = 18;
		result.color = 0x8ed6ff;
		result.x = x;
		result.y = y;
		result.mouseEnabled = true;
		result.addEventListener(MouseEvent.CLICK, _ -> {
			callback();
		});
		addChild(result);
		return result;
	}

	/** 仅供示例使用的平滑 UV 球，显式法线避免 UV 接缝形成硬边。 */
	private function createSphere():Geometry3D {
		var positions:Array<Float> = [],
			normals:Array<Float> = [],
			uvs:Array<Float> = [],
			indices:Array<Int> = [];
		var segments = 48, rings = 24;
		for (ring in 0...(rings + 1))
			for (segment in 0...(segments + 1)) {
				var theta = ring * Math.PI / rings,
					phi = segment * Math.PI * 2 / segments;
				var x = Math.sin(theta) * Math.cos(phi),
					y = Math.cos(theta),
					z = Math.sin(theta) * Math.sin(phi);
				for (value in [x * 0.65, y * 0.65, z * 0.65])
					positions.push(value);
				for (value in [x, y, z])
					normals.push(value);
				uvs.push(segment / segments);
				uvs.push(ring / rings);
			}
		for (ring in 0...rings)
			for (segment in 0...segments) {
				var a = ring * (segments + 1) + segment, b = a + segments + 1;
				if (ring > 0)
					for (index in [a, a + 1, b])
						indices.push(index);
				if (ring < rings - 1)
					for (index in [a + 1, b + 1, b])
						indices.push(index);
			}
		return new Geometry3D(positions, uvs, indices, normals);
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		if (cameraInput != null)
			cameraInput.dispose();
		if (cameraControl != null)
			cameraControl.dispose();
		super.dispose();
		if (environment != null) environment.dispose();
		if (environmentAssets != null) environmentAssets.clean();
		if (modelAssets != null) modelAssets.clean();
		for (geometry in geometries)
			geometry.dispose();
		for (material in materials)
			material.dispose();
		geometries = [];
		materials = [];
		originalPbrParameters = [];
		mappedMaterials = []; pbrMeshes = []; mapControls = [];
	}
}
