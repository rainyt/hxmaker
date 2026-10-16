package;

import hx.assets.Assets;
import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.Camera3D;
import hx.display.Label;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Node3D;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;

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
	private var loading:Bool = false;
	private var autoRotate:Bool = true;
	private var groundVisible:Bool = false;
	private var dragging:Bool = false;
	private var previousX:Float;
	private var statusTime:Float = 0;
	public function new() {
		super();
		var engine = Hxmaker.init(Engine, 960, 640); engine.initOpenFLRoot(this);
		var stage = Hxmaker.topView;
		stage.addChild(new Quad(960, 640, 0x172033));
		label("GLB 模型：T-Rex · 无光照预览", 24, 20, 25, 0xffffff);
		animationButton = action("动画：待加载", 24, toggleAnimation);
		rotateButton = action("旋转：开启", 175, function() { autoRotate = !autoRotate; updateButtons(); });
		textureButton = action("多纹理：开启", 325, function() { scene.multiTextureEnabled = !scene.multiTextureEnabled; updateButtons(); });
		groundButton = action("地面：隐藏", 495, function() {
			groundVisible = !groundVisible; applyGroundVisibility(); updateButtons();
		});
		action("重新取景", 650, fitModel); action("重新加载", 800, loadModel);
		scene = new Scene3D(912, 448); scene.x = 24; scene.y = 110; scene.backgroundColor = 0x24334d; scene.backgroundAlpha = 1;
		stage.addChild(scene);
		pivot = new Node3D(); scene.root.addChild(pivot);
		camera = new Camera3D(); camera.z = 10; scene.root.addChild(camera); scene.camera = camera;
		status = label("准备加载模型", 24, 571, 16, 0xd7e3fc);
		detail = label("拖动视口旋转模型；模型颜色遵循文件中的灰色材质。", 24, 602, 14, 0xa9bad6);
		scene.addEventListener(MouseEvent.MOUSE_DOWN, function(event:MouseEvent) { dragging = true; previousX = event.stageX; autoRotate = false; updateButtons(); });
		stage.addEventListener(MouseEvent.MOUSE_MOVE, function(event:MouseEvent) {
			if (dragging) { pivot.rotationY += (event.stageX - previousX)*0.5; previousX = event.stageX; }
		});
		stage.addEventListener(MouseEvent.MOUSE_UP, function(_) { dragging = false; });
		scene.addEventListener(MouseEvent.MOUSE_OUT, function(_) { dragging = false; });
		scene.addEventListener(Event.UPDATE, function(_) {
			var dt = Hxmaker.engine.dt;
			if (model != null) {
				model.update(dt); if (autoRotate) pivot.rotationY += dt*12;
				statusTime += dt;
				if (statusTime >= 0.2) {
					statusTime = 0;
					status.data = "动画：" + (model.animation.currentName == null ? "无" : model.animation.currentName)
						+ "　时间：" + (Math.round(model.animation.time*100)/100) + " 秒　3D 批次：" + scene.stats.drawCalls
						+ "　可见网格：" + scene.stats.visibleMeshes + "　三角形：" + scene.stats.triangles;
				}
			}
		});
		loadModel();
	}
	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color;
		Hxmaker.topView.addChild(result); return result;
	}
	private function action(text:String, x:Float, callback:Void->Void):Label {
		var result = label(text, x, 68, 17, 0x8ed6ff);
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
		detail.data = "通过 Assets / GlbFuture / BytesFuture 加载 assets/model.glb";
		assets.loadGlb("assets/model.glb");
		assets.onProgress(value -> { status.data = "加载进度：" + Math.round(value*100) + "%"; });
		assets.onError(error -> {
			loading = false; status.color = 0xff9b91; status.data = "GLB 加载失败"; detail.data = error.error;
			trace(error.toString());
		});
		assets.onComplete(_ -> {
			try {
				var asset = assets.getGlb("model");
				#if hxmaker_glb_checks
				GlbRegression.run(asset);
				#end
				model = asset.createInstance(); pivot.addChild(model);
				applyGroundVisibility();
				if (model.animation.names.length > 0) model.animation.play(model.animation.names[0], true);
				fitModel(); updateButtons();
				status.data = "加载完成：100%";
				detail.data = "源模型：" + asset.meshCount + " 个网格、" + asset.triangleCount + " 个三角形；浅灰材质，无贴图、无光照。";
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
		if (model == null || model.animation.names.length == 0) return;
		if (model.animation.playing) model.animation.pause(); else model.animation.resume(); updateButtons();
	}
	private function updateButtons():Void {
		animationButton.data = model == null ? "动画：待加载" : model.animation.names.length == 0 ? "动画：无" : "动画：" + (model.animation.playing ? "播放" : "暂停");
		rotateButton.data = "旋转：" + (autoRotate ? "开启" : "关闭");
		textureButton.data = "多纹理：" + (scene.multiTextureEnabled ? "开启" : "关闭");
		groundButton.data = "地面：" + (groundVisible ? "显示" : "隐藏");
	}
	private function applyGroundVisibility():Void {
		if (model != null) for (mesh in model.meshes) if (mesh.name == "Preview Ground") mesh.visible = groundVisible;
	}
	private function fitModel():Void {
		if (model == null) return;
		// 此资产附带的展示地面不参与角色取景；规则只存在于示例，不进入加载器。
		var bounds = model.getBounds(function(mesh:MeshObject) { return mesh.name != "Preview Ground"; });
		if (bounds.isEmpty()) return;
		var center = bounds.center(), dx = bounds.max.x - bounds.min.x, dy = bounds.max.y - bounds.min.y, dz = bounds.max.z - bounds.min.z;
		var radius = Math.max(0.01, Math.sqrt(dx*dx + dy*dy + dz*dz)/2);
		model.setPosition(-center.x, -center.y, -center.z); pivot.rotationY = 0;
		var vertical = camera.fieldOfView*Math.PI/360, horizontal = Math.atan(Math.tan(vertical)*scene.width/scene.height);
		var distance = radius / Math.sin(Math.min(vertical, horizontal))*1.15;
		camera.near = Math.max(0.01, distance - radius*2); camera.far = distance + radius*12;
		camera.setPosition(distance*0.75, distance*0.25, distance*0.85); camera.lookAt(new Vector3D());
	}
}
