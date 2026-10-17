package;

import hx.assets.Assets;
import hx.core.Engine;
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
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.material.LambertTextureMaterial;

/** 通过 hxmaker 加载 GLB，示范独立模型实例、蒙皮动画及已有批处理。 */
class Main extends openfl.display.Sprite {
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
	public function new() {
		super();
		var engine = Hxmaker.init(Engine, 960, 640); engine.initOpenFLRoot(this);
		var stage = Hxmaker.topView;
		stage.addChild(new Quad(960, 640, 0x172033));
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
			fixtureMode = !fixtureMode; fixtureRoot.visible = fixtureMode; if (model != null) model.visible = !fixtureMode;
			fitModel(); updateButtons();
		}, 101);
		action("切换光向", 720, function() {
			alternateDirection = !alternateDirection;
			light.direction = alternateDirection ? new Vector3D(1,-2,-0.5) : new Vector3D(-1,-2,-1);
		}, 101);
		scene = new Scene3D(912, 414); scene.x = 24; scene.y = 140; scene.backgroundColor = 0x24334d; scene.backgroundAlpha = 1;
		stage.addChild(scene);
		pivot = new Node3D(); scene.root.addChild(pivot);
		light = new DirectionalLight3D(0xffffff, 0.9); scene.root.addChild(light); scene.light = light;
		light.shadowEnabled = true; scene.ambientIntensity = 0.22;
		createFixture();
		camera = new Camera3D(); camera.z = 10; scene.root.addChild(camera); scene.camera = camera;
		status = label("准备加载模型", 24, 571, 15, 0xd7e3fc);
		detail = label("拖动旋转；可切换方块场景，观察明暗和地面阴影。", 24, 602, 14, 0xa9bad6);
		scene.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent) { dragging = true; previousX = event.stageX; autoRotate = false; updateButtons(); });
		stage.addEventListener(MouseEvent.MOUSE_MOVE, function(event:MouseEvent) {
			if (dragging) { pivot.rotationY += (event.stageX - previousX)*0.5; previousX = event.stageX; }
		});
		stage.addEventListener(MouseEvent.MOUSE_UP, function(_) { dragging = false; });
		scene.addEventListener(MouseEvent.MOUSE_OUT, function(_) { dragging = false; });
		scene.addEventListener(Event.UPDATE, function(_) {
			var dt = Hxmaker.engine.dt;
			if (model != null || fixtureMode) {
				if (model != null && !fixtureMode) model.update(dt);
				if (autoRotate) pivot.rotationY += dt*12;
				statusTime += dt;
				if (statusTime >= 0.2) {
					statusTime = 0;
					var animation = fixtureMode ? "方块" : (model.animation.currentName == null ? "无" : model.animation.currentName)
						+ " " + (Math.round(model.animation.time*100)/100) + "s";
					status.data = "主批次：" + scene.stats.drawCalls + "　阴影批次：" + scene.stats.shadowDrawCalls
						+ "　阴影：" + scene.stats.shadowStatus + "　动画：" + animation;
				}
			}
		});
		loadModel();
	}
	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color;
		Hxmaker.topView.addChild(result); return result;
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
		assets.onProgress(value -> { status.data = "加载进度：" + Math.round(value*100) + "%"; });
		assets.onError(error -> {
			loading = false; status.color = 0xff9b91; status.data = "GLB 加载失败"; detail.data = error.error;
			trace(error.toString());
		});
		assets.onComplete(_ -> {
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
		sceneButton.data = "场景：" + (fixtureMode ? "方块" : "恐龙");
	}
	private function applyGroundVisibility():Void {
		if (model != null) for (mesh in model.meshes) if (mesh.name == "Preview Ground") mesh.visible = groundVisible;
		fixtureFloor.visible = groundVisible;
	}
	private function applyLighting():Void {
		if (model != null) for (mesh in model.meshes) mesh.material.lightingEnabled = lightingEnabled;
		cube.material.lightingEnabled = fixtureFloor.material.lightingEnabled = lightingEnabled;
	}
	private function createFixture():Void {
		fixtureRoot = new Node3D(); pivot.addChild(fixtureRoot); fixtureRoot.visible = false;
		cube = new MeshObject(BoxGeometry.create(2,2,2), new LambertTextureMaterial(null, 0xe5b05d));
		cube.setScale(1,0.8,1.4); cube.y = 0.8; cube.castShadow = true; fixtureRoot.addChild(cube);
		fixtureFloor = new MeshObject(PlaneGeometry.create(12,12), new LambertTextureMaterial(null, 0x6d8096));
		fixtureFloor.castShadow = false; fixtureFloor.receiveShadow = true; fixtureRoot.addChild(fixtureFloor);
	}
	private function fitModel():Void {
		if (model == null && !fixtureMode) return;
		// 此资产附带的展示地面不参与角色取景；规则只存在于示例，不进入加载器。
		var bounds = fixtureMode ? cube.geometry.bounds.transformed(cube.getLocalMatrix())
			: model.getBounds(function(mesh:MeshObject) { return mesh.name != "Preview Ground"; });
		if (bounds.isEmpty()) return;
		var center = bounds.center(), dx = bounds.max.x - bounds.min.x, dy = bounds.max.y - bounds.min.y, dz = bounds.max.z - bounds.min.z;
		var radius = Math.max(0.01, Math.sqrt(dx*dx + dy*dy + dz*dz)/2);
		if (fixtureMode) fixtureRoot.setPosition(-center.x, -center.y, -center.z); else model.setPosition(-center.x, -center.y, -center.z);
		pivot.rotationY = 0;
		var vertical = camera.fieldOfView*Math.PI/360, horizontal = Math.atan(Math.tan(vertical)*scene.width/scene.height);
		var distance = radius / Math.sin(Math.min(vertical, horizontal))*1.15;
		camera.near = Math.max(0.01, distance - radius*2); camera.far = distance + radius*12;
		camera.setPosition(distance*0.75, distance*0.25, distance*0.85); camera.lookAt(new Vector3D());
	}
}
