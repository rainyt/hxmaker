package;

import hx.assets.Assets;
import hx.display.Stage;
import hx.core.Hxmaker;
import hx.display3d.Camera3D;
import hx.display.Label;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import hx.display3d.Node3D;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;
import hx.light.ShadowFilter3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.material.LambertTextureMaterial;

/** 通过 hxmaker 加载 GLB，示范独立模型实例、蒙皮动画及已有批处理。 */
class GameStage extends Stage {
	private var assets:Assets;
	private var scene:Scene3D;
	private var camera:Camera3D;
	private var pivot:Node3D;
	private var model:Model3D;
	private var status:Label;
	private var detail:Label;
	private var animationButton:Label;
	private var rotateButton:Label;
	private var textureButton:Label;
	private var groundButton:Label;
	private var lightButton:Label;
	private var shadowButton:Label;
	private var sizeButton:Label;
	private var sceneButton:Label;
	private var filterButton:Label;
	private var updateButton:Label;
	private var maskButton:Label;
	private var shadowDetail:Label;
	private var maskAssets:Assets;
	private var maskRoot:Node3D;
	private var maskPlane:MeshObject;
	private var maskMode:Bool = false;
	private var light:DirectionalLight3D;
	private var lightingEnabled:Bool = true;
	private var fixtureMode:Bool = false;
	private var fixtureRoot:Node3D;
	private var cube:MeshObject;
	private var fixtureFloor:MeshObject;
	private var alternateDirection:Bool = false;
	private var loading:Bool = false;
	private var autoRotate:Bool = true;
	private var groundVisible:Bool = true;
	private var dragging:Bool = false;
	private var previousX:Float;
	private var statusTime:Float = 0;
	override public function onStageInit():Void {
		super.onStageInit();
		addChild(new Quad(960, 640, 0x172033));
		label("GLB 模型：T-Rex · 方向光与阴影", 24, 20, 25, 0xffffff);
		animationButton = action("动画：待加载", 24, toggleAnimation);
		rotateButton = action("旋转：开启", 175, function() { autoRotate = !autoRotate; updateButtons(); });
		textureButton = action("多纹理：开启", 325, function() { scene.multiTextureEnabled = !scene.multiTextureEnabled; updateButtons(); });
		groundButton = action("地面：显示", 495, function() {
			groundVisible = !groundVisible; applyGroundVisibility(); updateButtons();
		});
		action("重新取景", 650, fitModel); action("重新加载", 800, loadModel);
		lightButton = action("光照：开启", 24, function() { lightingEnabled = !lightingEnabled; applyLighting(); updateButtons(); }, 101);
		shadowButton = action("阴影：开启", 175, function() { light.shadowEnabled = !light.shadowEnabled; updateButtons(); }, 101);
		sizeButton = action("阴影图：1024", 325, function() { light.shadowMapSize = light.shadowMapSize == 1024 ? 512 : 1024; updateButtons(); }, 101);
		sceneButton = action("场景：恐龙", 510, function() {
			if (!fixtureMode) { fixtureMode = true; maskMode = false; }
			else if (!maskMode) maskMode = true;
			else { fixtureMode = false; maskMode = false; }
			fixtureRoot.visible = fixtureMode; cube.visible = !maskMode; maskRoot.visible = maskMode;
			if (model != null) model.visible = !fixtureMode;
			fitModel(); updateButtons();
		}, 101);
		action("切换光向", 720, function() {
			alternateDirection = !alternateDirection;
			light.direction = alternateDirection ? new Vector3D(1,-2,-0.5) : new Vector3D(-1,-2,-1);
		}, 101);
		filterButton = action("过滤：硬阴影", 24, function() {
			light.shadowFilter = light.shadowFilter == ShadowFilter3D.HARD ? ShadowFilter3D.PCF4 : ShadowFilter3D.HARD;
			updateButtons();
		}, 134);
		updateButton = action("更新：自动", 205, function() {
			light.shadowAutoUpdate = !light.shadowAutoUpdate; updateButtons();
		}, 134);
		action("立即更新阴影", 375, function() { light.requestShadowUpdate(); }, 134);
		maskButton = action("轮廓：镂空", 565, function() {
			maskPlane.material.alphaMode = maskPlane.material.alphaMode == AlphaMode3D.MASK ? AlphaMode3D.OPAQUE : AlphaMode3D.MASK;
			updateButtons();
		}, 134);
		action("仅转动相机", 755, function() {
			autoRotate = false;
			if (model != null) model.animation.pause();
			var x = camera.x, z = camera.z, angle = Math.PI / 12;
			camera.x = x*Math.cos(angle)+z*Math.sin(angle); camera.z = z*Math.cos(angle)-x*Math.sin(angle);
			camera.lookAt(new Vector3D()); updateButtons();
		}, 134);
		scene = new Scene3D(912, 370); scene.x = 24; scene.y = 170; scene.backgroundColor = 0x24334d; scene.backgroundAlpha = 1;
		addChild(scene);
		pivot = new Node3D(); scene.root.addChild(pivot);
		light = new DirectionalLight3D(0xffffff, 0.9); scene.root.addChild(light); scene.light = light;
		light.shadowEnabled = true; light.shadowMapSize = 512; light.shadowFilter = ShadowFilter3D.HARD;
		light.shadowAutoUpdate = true; scene.ambientIntensity = 0.22;
		createFixture();
		camera = new Camera3D(); camera.z = 10; scene.root.addChild(camera); scene.camera = camera;
		status = label("准备加载模型", 24, 552, 14, 0xd7e3fc);
		shadowDetail = label("阴影统计：等待首次绘制", 24, 577, 14, 0xa9bad6);
		detail = label("场景可切换恐龙、方块和镂空；关闭旋转后，仅转相机观察缓存。", 24, 604, 13, 0xa9bad6);
		scene.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent) { dragging = true; previousX = event.stageX; autoRotate = false; updateButtons(); });
		addEventListener(MouseEvent.MOUSE_MOVE, function(event:MouseEvent) {
			if (dragging) { pivot.rotationY += (event.stageX - previousX)*0.5; previousX = event.stageX; }
		});
		addEventListener(MouseEvent.MOUSE_UP, function(_) { dragging = false; });
		scene.addEventListener(MouseEvent.MOUSE_OUT, function(_) { dragging = false; });
		scene.addEventListener(Event.UPDATE, function(_) {
			var dt = Hxmaker.engine.dt;
			if (model != null || fixtureMode) {
				if (model != null && !fixtureMode) model.update(dt);
				if (autoRotate) pivot.rotationY += dt*12;
				statusTime += dt;
				if (statusTime >= 0.2) {
					statusTime = 0;
					shadowDetail.data = "最近重绘：" + (scene.stats.shadowMapSize == 0 ? "无阴影" : scene.stats.shadowCacheHit ? "复用阴影" : "更新阴影")
						+ "　上传：" + scene.stats.shadowUploadedBytes + " B　尺寸：" + scene.stats.shadowMapSize
						+ "　过滤：" + (light.shadowFilter == ShadowFilter3D.HARD ? "硬阴影" : "PCF4")
						+ "　更新：" + (light.shadowAutoUpdate ? "自动" : "手动");
					var animation = fixtureMode ? (maskMode ? "镂空" : "方块") : (model.animation.currentName == null ? "无" : model.animation.currentName)
						+ " " + (Math.round(model.animation.time*100)/100) + "s";
					status.data = "主批次：" + scene.stats.drawCalls + "　阴影批次：" + scene.stats.shadowDrawCalls
						+ "　阴影：" + scene.stats.shadowStatus + "　动画：" + animation;
				}
			}
		});
		loadModel();
		loadMaskTexture();
	}
	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color;
		addChild(result); return result;
	}
	private function action(text:String, x:Float, callback:Void->Void, y:Float = 68):Label {
		var result = label(text, x, y, 17, 0x8ed6ff);
		result.addEventListener(MouseEvent.CLICK, function(_) { callback(); }); return result;
	}
	private function loadModel():Void {
		if (loading) return;
		loading = true; dragging = false;
		if (model != null) { model.dispose(); model = null; }
		if (assets != null) assets.clean();
		statusTime = 0; updateButtons();
		assets = new Assets(); assets.tryLoadTimes = 0;
		status.color = 0xd7e3fc; status.data = "加载进度：0%";
		detail.data = "通过 Assets / ModelFuture / BytesFuture 加载 assets/model.glb";
		assets.loadModel("assets/model.glb");
		assets.onProgress(value -> { if (isDisposed) return; status.data = "加载进度：" + Math.round(value*100) + "%"; });
		assets.onError(error -> {
			if (isDisposed) return;
			loading = false; status.color = 0xff9b91; status.data = "GLB 加载失败"; detail.data = error.error;
			trace(error.toString());
		});
		assets.onComplete(_ -> {
			if (isDisposed) return;
			try {
				var asset = assets.getModel("model");
				#if hxmaker_glb_checks
				GlbRegression.run(asset);
				#end
				model = asset.createInstance(-1, {lightingEnabled:true}); pivot.addChild(model); model.visible = !fixtureMode;
				for (mesh in model.meshes) { mesh.castShadow = mesh.name != "Preview Ground"; mesh.receiveShadow = true; }
				applyLighting();
				applyGroundVisibility();
				if (model.animation.names.length > 0) model.animation.play(model.animation.names[0], true);
				fitModel(); updateButtons();
				status.data = "加载完成：100%";
				detail.data = "源模型：" + asset.meshCount + " 网格、" + asset.triangleCount + " 三角形；拖动旋转，切换光向观察阴影。";
				for (warning in asset.warnings) trace("GLB 提示：" + warning);
			} catch (error:Dynamic) {
				if (model != null) { model.dispose(); model = null; }
				status.color = 0xff9b91; status.data = "模型实例化失败"; detail.data = Std.string(error);
				trace(Std.string(error));
			}
			loading = false;
		});
		assets.start();
	}
	private function toggleAnimation():Void {
		if (fixtureMode || model == null || model.animation.names.length == 0) return;
		if (model.animation.playing) model.animation.pause(); else model.animation.resume(); updateButtons();
	}
	private function updateButtons():Void {
		animationButton.data = fixtureMode ? "动画：不适用" : model == null ? "动画：待加载" : model.animation.names.length == 0 ? "动画：无" : "动画：" + (model.animation.playing ? "播放" : "暂停");
		rotateButton.data = "旋转：" + (autoRotate ? "开启" : "关闭");
		textureButton.data = "多纹理：" + (scene.multiTextureEnabled ? "开启" : "关闭");
		groundButton.data = "地面：" + (groundVisible ? "显示" : "隐藏");
		lightButton.data = "光照：" + (lightingEnabled ? "开启" : "关闭");
		shadowButton.data = "阴影：" + (light.shadowEnabled ? "开启" : "关闭");
		sizeButton.data = "阴影图：" + light.shadowMapSize;
		sceneButton.data = "场景：" + (fixtureMode ? (maskMode ? "镂空" : "方块") : "恐龙");
		filterButton.data = "过滤：" + (light.shadowFilter == ShadowFilter3D.HARD ? "硬阴影" : "PCF4");
		updateButton.data = "更新：" + (light.shadowAutoUpdate ? "自动" : "手动");
		maskButton.data = "轮廓：" + (maskPlane.material.alphaMode == AlphaMode3D.MASK ? "镂空" : "矩形");
	}
	private function applyGroundVisibility():Void {
		if (model != null) for (mesh in model.meshes) if (mesh.name == "Preview Ground") mesh.visible = groundVisible;
		fixtureFloor.visible = groundVisible;
	}
	private function applyLighting():Void {
		if (model != null) for (mesh in model.meshes) mesh.material.lightingEnabled = lightingEnabled;
		cube.material.lightingEnabled = fixtureFloor.material.lightingEnabled = maskPlane.material.lightingEnabled = lightingEnabled;
	}
	private function createFixture():Void {
		fixtureRoot = new Node3D(); pivot.addChild(fixtureRoot); fixtureRoot.visible = false;
		cube = new MeshObject(BoxGeometry.create(2,2,2), new LambertTextureMaterial(null, 0xe5b05d));
		cube.setScale(1,0.8,1.4); cube.y = 0.8; cube.castShadow = true; fixtureRoot.addChild(cube);
		fixtureFloor = new MeshObject(PlaneGeometry.create(12,12), new LambertTextureMaterial(null, 0x6d8096));
		fixtureFloor.castShadow = false; fixtureFloor.receiveShadow = true; fixtureRoot.addChild(fixtureFloor);
		maskRoot = new Node3D(); fixtureRoot.addChild(maskRoot); maskRoot.visible = false;
		var material = new LambertTextureMaterial(); material.alphaMode = AlphaMode3D.MASK;
		material.alphaCutoff = 0.5; material.cullMode = CullMode3D.NONE;
		maskPlane = new MeshObject(PlaneGeometry.create(3, 3), material);
		maskPlane.y = 2; maskPlane.castShadow = true; maskPlane.visible = false; maskRoot.addChild(maskPlane);
	}
	private function loadMaskTexture():Void {
		// 使用独立资源组，重新加载 GLB 时不会释放镂空示例仍在使用的纹理。
		maskAssets = new Assets(); maskAssets.tryLoadTimes = 0;
		maskAssets.loadBitmapData("assets/shadow-mask.png");
		maskAssets.onComplete(_ -> {
			if (isDisposed) return;
			maskPlane.material.texture = maskAssets.getBitmapData("shadow-mask"); maskPlane.visible = true;
		});
		maskAssets.onError(error -> {
			if (isDisposed) return;
			maskPlane.visible = false;
			detail.data = "镂空纹理加载失败：" + error.error; trace(error.toString());
		});
		maskAssets.start();
	}
	/** 先销毁场景中的资源引用，再释放示例持有的几何、材质和纹理。 */
	override public function dispose():Void {
		if (isDisposed) return;
		var geometries = new Array<hx.geometry.Geometry3D>();
		var materials = new Array<hx.material.Material3D>();
		for (mesh in [cube, fixtureFloor, maskPlane]) if (mesh != null) {
			geometries.push(mesh.geometry); materials.push(mesh.material);
		}
		super.dispose();
		for (geometry in geometries) if (geometry != null) geometry.dispose();
		for (material in materials) if (material != null) material.dispose();
		if (assets != null) assets.clean();
		if (maskAssets != null) maskAssets.clean();
	}
	private function fitModel():Void {
		if (model == null && !fixtureMode) return;
		// 此资产附带的展示地面不参与角色取景；规则只存在于示例，不进入加载器。
		var bounds = fixtureMode ? (maskMode ? maskPlane.geometry.bounds.transformed(maskPlane.getLocalMatrix()) : cube.geometry.bounds.transformed(cube.getLocalMatrix()))
			: model.getBounds(function(mesh:MeshObject) { return mesh.name != "Preview Ground"; });
		if (bounds.isEmpty()) return;
		if (fixtureMode && maskMode) bounds.include(0, 0, 0);
		var center = bounds.center(), dx = bounds.max.x - bounds.min.x, dy = bounds.max.y - bounds.min.y, dz = bounds.max.z - bounds.min.z;
		var radius = Math.max(0.01, Math.sqrt(dx*dx + dy*dy + dz*dz)/2);
		if (fixtureMode) fixtureRoot.setPosition(-center.x, -center.y, -center.z); else model.setPosition(-center.x, -center.y, -center.z);
		pivot.rotationY = 0;
		var vertical = camera.fieldOfView*Math.PI/360, horizontal = Math.atan(Math.tan(vertical)*scene.width/scene.height);
		var distance = radius / Math.sin(Math.min(vertical, horizontal))*1.15;
		camera.near = Math.max(0.01, distance - radius*2); camera.far = distance + radius*12;
		camera.setPosition(distance*0.75, distance*(fixtureMode && maskMode ? 0.85 : 0.25), distance*0.85); camera.lookAt(new Vector3D());
	}
}
