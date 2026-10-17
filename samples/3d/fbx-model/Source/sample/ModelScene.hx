package sample;

import haxe.io.Path;
import hx.assets.Assets;
import hx.assets.ModelAsset;
import hx.display.Image;
import hx.display.Label;
import hx.display.Scene;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import hx.display3d.Node3D;
import hx.events.MouseEvent;
import hx.geom.Bounds3D;
import hx.geom.Vector3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.material.LambertTextureMaterial;
import hx.material.CullMode3D;

/** 使用同一个 loadModel 接口对照 ASCII FBX、二进制 FBX 和 GLB，不自动执行断言。 */
class ModelScene extends Scene {
	private var files:Array<String> = ["robot-ascii.fbx", "robot-binary-7400.fbx", "robot-binary-7500.fbx", "robot.glb"];
	private var view:Scene3D;
	private var pivot:Node3D;
	private var camera:Camera3D;
	private var floor:MeshObject;
	private var light:DirectionalLight3D;
	private var assets:Assets;
	private var source:ModelAsset;
	private var models:Array<Model3D> = [];
	private var colors:Array<Int> = [];
	private var preview:Image;
	private var status:Label;
	private var detail:Label;
	private var warning:Label;
	private var generation:Int = 0;
	private var currentFile:String;
	private var rotating:Bool = true;
	private var lighting:Bool = true;
	private var tinted:Bool = false;
	private var dragging:Bool = false;
	private var lastX:Float = 0;
	private var statusTime:Float = 0;

	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true;
		sceneBackground.data = 0x172033; sceneBackground.alpha = 1;
		label("统一模型加载 · FBX / GLB", 24, 18, 25, 0xffffff);
		for (i in 0...files.length) {
			var file = files[i];
			button(file, 24 + i * 245, 65, () -> load(file));
		}
		button("重新加载", 24, 104, () -> load(currentFile));
		button("自动旋转 开/关", 175, 104, () -> { rotating = !rotating; });
		button("光照 开/关", 370, 104, () -> {
			lighting = !lighting;
			for (model in models) for (mesh in model.meshes) mesh.material.lightingEnabled = lighting;
		});
		button("首个实例变色", 540, 104, changeColor);
		button("重新取景", 725, 104, fit);
		button("自有 custom.fbx", 24, 141, () -> load("custom.fbx"));
		button("阴影 开/关", 270, 141, () -> { light.shadowEnabled = !light.shadowEnabled; });
		button("多纹理 开/关", 470, 141, () -> { view.multiTextureEnabled = !view.multiTextureEnabled; });
		view = new Scene3D(992, 420); view.x = 24; view.y = 182;
		view.backgroundColor = 0x24334d; view.backgroundAlpha = 1; view.ambientIntensity = 0.35; addChild(view);
		pivot = new Node3D(); view.root.addChild(pivot);
		camera = new Camera3D(); view.root.addChild(camera); view.camera = camera;
		light = new DirectionalLight3D(0xffffff, 0.85); light.direction = new Vector3D(-1,-2,-1);
		light.shadowEnabled = true; view.root.addChild(light); view.light = light;
		var material = new LambertTextureMaterial(null, 0x63778c); material.cullMode = CullMode3D.NONE;
		floor = new MeshObject(PlaneGeometry.create(12,12), material); floor.y = -0.015; view.root.addChild(floor);
		status = label("准备加载", 24, 618, 16, 0xd7e3fc);
		detail = label("", 24, 650, 14, 0xa9bad6);
		warning = label("", 95, 685, 13, 0xffd38a); warning.width = 915; warning.height = 55;
		view.addEventListener(MouseEvent.MOUSE_DOWN, (event:MouseEvent) -> { dragging = true; rotating = false; lastX = event.stageX; });
		view.addEventListener(MouseEvent.MOUSE_MOVE, (event:MouseEvent) -> {
			if (dragging) { pivot.rotationY += (event.stageX - lastX) * 0.5; lastX = event.stageX; }
		});
		view.addEventListener(MouseEvent.MOUSE_UP, _ -> { dragging = false; });
		view.addEventListener(MouseEvent.MOUSE_OUT, _ -> { dragging = false; });
		load(files[0]);
	}

	private function load(file:String):Void {
		if (file == null || isDisposed) return;
		currentFile = file; var version = ++generation;
		clearModels();
		if (assets != null) { assets.stop(); assets.clean(); }
		var request = new Assets(); assets = request; request.tryLoadTimes = 0;
		status.color = 0xd7e3fc; status.data = "加载中：" + file; detail.data = ""; warning.data = "";
		request.loadModel("assets/" + file);
		request.onError(error -> {
			request.stop(); request.clean();
			if (isDisposed || version != generation) return;
			status.color = 0xff9b91; status.data = "加载失败：" + file;
			warning.data = error.error; trace(error.toString());
		});
		request.onComplete(_ -> {
			if (isDisposed || version != generation) { request.clean(); return; }
			try {
				source = request.getModel(Path.withoutExtension(file));
				createModels();
				if (source.textureCount > 0) {
					preview = new Image(source.getTexture(0)); preview.x = 24; preview.y = 685; preview.width = preview.height = 52; preview.smoothing = false; addChild(preview);
				}
				var stats = source.buildStats;
				detail.data = "来源：" + source.sourceFormat + "　网格：" + source.meshCount + "　图元：" + stats.primitiveCount
					+ "　顶点：" + stats.vertexCount + "　三角形：" + stats.triangleCount + "　图片：" + source.imageCount;
				warning.data = source.warnings.join("\n");
				for (message in source.warnings) trace("模型提示：" + message);
				statusTime = 1;
			} catch (error:Dynamic) {
				clearModels(); request.clean(); status.color = 0xff9b91;
				status.data = "实例化失败：" + file; warning.data = Std.string(error); trace(error);
			}
		});
		request.start();
	}

	private function createModels():Void {
		var first = source.createInstance(-1, {lightingEnabled: lighting}); models.push(first);
		var bounds = first.getBounds();
		if (bounds.isEmpty()) throw "模型没有可显示的边界";
		var center = bounds.center(), gap = Math.max(0.8, (bounds.max.x - bounds.min.x) * 0.8);
		first.setPosition(-center.x - gap, -bounds.min.y, -center.z); pivot.addChild(first);
		var second = source.createInstance(-1, {lightingEnabled: lighting}); models.push(second);
		second.setPosition(-center.x + gap, -bounds.min.y, -center.z); pivot.addChild(second);
		for (model in models) for (mesh in model.meshes) { mesh.castShadow = true; mesh.receiveShadow = true; }
		colors = [for (mesh in first.meshes) mesh.material.color]; tinted = false;
		fit();
	}

	private function changeColor():Void {
		if (models.length == 0) return;
		tinted = !tinted;
		var meshes = models[0].meshes;
		for (i in 0...meshes.length) meshes[i].material.color = tinted ? 0xff8877 : colors[i];
	}

	private function fit():Void {
		if (models.length == 0) return;
		pivot.rotationY = 0;
		var bounds = new Bounds3D();
		for (model in models) {
			var local = model.getBounds().transformed(model.getLocalMatrix());
			bounds.include(local.min.x, local.min.y, local.min.z); bounds.include(local.max.x, local.max.y, local.max.z);
		}
		var center = bounds.center(), dx = bounds.max.x - bounds.min.x, dy = bounds.max.y - bounds.min.y, dz = bounds.max.z - bounds.min.z;
		var radius = Math.max(0.1, Math.sqrt(dx*dx + dy*dy + dz*dz) / 2);
		var angle = camera.fieldOfView * Math.PI / 360, distance = radius / Math.sin(angle) * 1.2;
		camera.near = Math.max(0.01, distance - radius * 2); camera.far = distance + radius * 12;
		camera.setPosition(center.x + distance * 0.7, center.y + distance * 0.35, center.z + distance * 0.85); camera.lookAt(center);
		floor.setScale(Math.max(1, radius / 3), 1, Math.max(1, radius / 3));
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (models.length == 0 || isDisposed) return;
		if (rotating) pivot.rotationY += dt * 15;
		for (model in models) model.update(dt);
		statusTime += dt;
		if (statusTime > 0.2) {
			statusTime = 0;
			status.data = currentFile + "　实例：" + models.length + "　主批次：" + view.stats.drawCalls
				+ "　阴影批次：" + view.stats.shadowDrawCalls + "　拖动可旋转";
		}
	}

	private function clearModels():Void {
		for (model in models) model.dispose(); models = []; colors = []; source = null; dragging = false;
		if (preview != null) { removeChild(preview); preview.dispose(); preview = null; }
	}

	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color; addChild(result); return result;
	}

	private function button(text:String, x:Float, y:Float, action:Void->Void):Void {
		var result = label(text, x, y, 16, 0x8ed6ff);
		result.addEventListener(MouseEvent.CLICK, _ -> action());
	}

	override public function dispose():Void {
		if (isDisposed) return;
		generation++;
		if (assets != null) assets.stop();
		clearModels();
		var geometry = floor == null ? null : floor.geometry, material = floor == null ? null : floor.material;
		super.dispose();
		if (geometry != null) geometry.dispose();
		if (material != null) material.dispose();
		if (assets != null) { assets.clean(); assets = null; }
	}
}
