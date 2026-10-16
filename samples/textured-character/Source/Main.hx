package;

import hx.assets.Assets;
import hx.assets.GlbAsset;
import hx.core.Engine;
import hx.core.Hxmaker;
import hx.display.Camera3D;
import hx.display.Image;
import hx.display.Label;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Node3D;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;

/** 仅通过 Assets 加载完整 GLB；贴图、骨骼与动画均来自内嵌资源。 */
class Main extends openfl.display.Sprite {
	private var assets:Assets;
	private var source:GlbAsset;
	private var scene:Scene3D;
	private var camera:Camera3D;
	private var pivot:Node3D;
	private var floor:MeshObject;
	private var light:DirectionalLight3D;
	private var models:Array<Model3D> = [];
	private var previews:Array<Image> = [];
	private var animationButton:Label;
	private var clipButton:Label;
	private var textureButton:Label;
	private var lightButton:Label;
	private var countButton:Label;
	private var shadowButton:Label;
	private var filterButton:Label;
	private var rotateButton:Label;
	private var status:Label;
	private var detail:Label;
	private var loading:Bool = false;
	private var playing:Bool = true;
	private var clip:String = "Walk";
	private var count:Int = 3;
	private var lighting:Bool = true;
	private var smoothing:Bool = true;
	private var rotating:Bool = false;
	private var dragging:Bool = false;
	private var previousX:Float = 0;
	private var statusTime:Float = 0;
	private var selectedName:String = "";

	public function new() {
		super();
		var engine = Hxmaker.init(Engine, 960, 720); engine.initOpenFLRoot(this);
		Hxmaker.topView.addChild(new Quad(960,720,0x172033));
		label("贴图动画角色 · Assets / GLB / 多纹理",24,19,25,0xffffff);
		animationButton = action("动画：播放",24,67,toggleAnimation);
		clipButton = action("动作：行走",205,67,function() { clip = clip == "Walk" ? "Idle" : "Walk"; startAnimations(); updateButtons(); });
		textureButton = action("多纹理：开启",390,67,function() { scene.multiTextureEnabled = !scene.multiTextureEnabled; updateButtons(); });
		lightButton = action("光照：开启",590,67,function() { lighting = !lighting; applyMaterials(); updateButtons(); });
		action("重新加载",785,67,loadModel);
		countButton = action("角色：3 个",24,106,function() { count = count == 1 ? 3 : count == 3 ? 6 : 1; createModels(); updateButtons(); });
		shadowButton = action("阴影：开启",205,106,function() { light.shadowEnabled = !light.shadowEnabled; updateButtons(); });
		filterButton = action("过滤：线性",390,106,function() { smoothing = !smoothing; applyMaterials(); updateButtons(); });
		rotateButton = action("旋转：关闭",590,106,function() { rotating = !rotating; updateButtons(); });
		action("重新取景",785,106,fitModels);

		scene = new Scene3D(912,432); scene.x = 24; scene.y = 148;
		scene.backgroundColor = 0x24334d; scene.backgroundAlpha = 1; scene.ambientIntensity = 0.35;
		Hxmaker.topView.addChild(scene);
		pivot = new Node3D(); scene.root.addChild(pivot);
		camera = new Camera3D(); scene.root.addChild(camera); scene.camera = camera;
		light = new DirectionalLight3D(0xffffff,0.85); light.direction = new Vector3D(-1,-2,-1);
		light.shadowEnabled = true; scene.root.addChild(light); scene.light = light;
		floor = new MeshObject(PlaneGeometry.create(30,30),new LambertTextureMaterial(null,0x708299));
		floor.material.cullMode = CullMode3D.NONE; floor.y = -0.06; floor.receiveShadow = true; scene.root.addChild(floor);
		floor.material.colorMultiplyLinear = true;
		status = label("准备加载角色",24,590,15,0xd7e3fc);
		detail = label("拖动旋转；切换多纹理，比较主场景批次与纹理槽位。",24,616,14,0xa9bad6);
		label("身体",24,690,12,0xa9bad6); label("面板",112,690,12,0xa9bad6); label("关节",200,690,12,0xa9bad6);
		label("左侧三张预览与 3D 角色共用 Assets 贴图。",302,651,14,0xa9bad6);
		label("图案方向：身体左上红标、左下绿标；面板眼睛在嘴巴上方。",302,677,13,0xa9bad6);
		scene.addEventListener(MouseEvent.MOUSE_DOWN,function(event:MouseEvent) {
			dragging = true; previousX = event.stageX; rotating = false;
			var hit = scene.pick(event.stageX,event.stageY);
			selectedName = hit == null ? "" : hit.object.name;
			updateButtons();
		});
		Hxmaker.topView.addEventListener(MouseEvent.MOUSE_MOVE,function(event:MouseEvent) {
			if (dragging) { pivot.rotationY += (event.stageX-previousX)*0.5; previousX = event.stageX; }
		});
		Hxmaker.topView.addEventListener(MouseEvent.MOUSE_UP,function(_) { dragging = false; });
		scene.addEventListener(MouseEvent.MOUSE_OUT,function(_) { dragging = false; });
		scene.addEventListener(Event.UPDATE,function(_) {
			var dt = Hxmaker.engine.dt;
			for (model in models) model.update(dt);
			if (rotating) pivot.rotationY += dt*12;
			statusTime += dt;
			if (!loading && models.length > 0 && statusTime >= 0.2) {
				statusTime = 0;
				status.data = "主批次：" + scene.stats.drawCalls + "　槽位：" + scene.stats.textureSlots
					+ "　阴影批次：" + scene.stats.shadowDrawCalls + "　角色：" + models.length
					+ "　动画：" + clip + " " + Math.round(models[0].animation.time*100)/100 + "s";
				detail.data = "可见网格：" + scene.stats.visibleMeshes + "　上传：" + Math.round(scene.stats.uploadedBytes/1024) + " KiB"
					+ "　阴影：" + scene.stats.shadowStatus + (selectedName == "" ? "" : "　选中：" + selectedName);
			}
		});
		loadModel();
	}
	private function label(text:String,x:Float,y:Float,size:Int,color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color;
		Hxmaker.topView.addChild(result); return result;
	}
	private function action(text:String,x:Float,y:Float,callback:Void->Void):Label {
		var result = label(text,x,y,17,0x8ed6ff);
		result.addEventListener(MouseEvent.CLICK,function(_) { callback(); }); return result;
	}
	private function disposeModels():Void {
		for (model in models) model.dispose(); models = [];
	}
	private function disposePreviews():Void {
		for (image in previews) {
			if (image.parent != null) image.parent.removeChild(image);
			image.data = null; image.dispose();
		}
		previews = [];
	}
	private function loadModel():Void {
		if (loading) return;
		loading = true; dragging = false; source = null; selectedName = "";
		disposeModels();
		// 先移除所有使用位图的对象，再释放 Assets 的源图片引用。
		disposePreviews();
		if (assets != null) assets.clean();
		assets = new Assets(); assets.tryLoadTimes = 0;
		status.color = 0xd7e3fc; status.data = "加载进度：0%";
		detail.data = "通过 Assets 加载 robot.glb，等待三张内嵌 PNG 解码完成。";
		assets.loadGlb("assets/robot.glb");
		assets.onProgress(value -> { status.data = "加载进度：" + Math.round(value*100) + "%"; });
		assets.onError(error -> {
			loading = false; assets.stop(); assets.clean(); status.color = 0xff9b91; status.data = "角色加载失败";
			detail.data = error.error; trace(error.toString());
		});
		assets.onComplete(_ -> {
			try {
				source = assets.getGlb("robot");
				#if hxmaker_character_checks
				CharacterChecks.run(source);
				#end
				createModels();
				for (i in 0...source.textureCount) {
					var image = new Image(source.getTexture(i)); image.width = 44; image.height = 44; image.x = 24+i*88; image.y = 642;
					Hxmaker.topView.addChild(image); previews.push(image);
				}
				for (warning in source.warnings) trace("GLB 提示：" + warning);
				status.data = "加载完成：3 张贴图、Idle / Walk 动画";
			} catch (error:Dynamic) {
				disposeModels(); disposePreviews();
				source = null; assets.clean(); status.color = 0xff9b91; status.data = "角色实例化失败"; detail.data = Std.string(error);
				trace(Std.string(error));
			}
			loading = false; updateButtons();
		});
		assets.start();
	}
	private function createModels():Void {
		if (source == null) return;
		disposeModels(); selectedName = "";
		for (i in 0...count) {
			var model = source.createInstance(-1,{lightingEnabled:lighting}); models.push(model); pivot.addChild(model);
			model.x = (i-(count-1)/2)*2.2;
			for (mesh in model.meshes) mesh.castShadow = true;
		}
		applyMaterials(); startAnimations(); fitModels();
	}
	private function startAnimations():Void {
		for (i in 0...models.length) {
			var animation = models[i].animation; animation.play(clip,true);
			animation.seek(animation.duration*i/Math.max(1,models.length));
			if (!playing) animation.pause();
		}
	}
	private function toggleAnimation():Void {
		playing = !playing;
		for (model in models) { if (playing) model.animation.resume(); else model.animation.pause(); }
		updateButtons();
	}
	private function applyMaterials():Void {
		for (model in models) for (mesh in model.meshes) {
			mesh.material.lightingEnabled = lighting; mesh.material.smoothing = smoothing; mesh.material.textureMinSmoothing = null;
		}
		floor.material.lightingEnabled = lighting; floor.material.smoothing = smoothing;
	}
	private function fitModels():Void {
		if (models.length == 0) return;
		pivot.rotationY = 0;
		var halfWidth = (models.length-1)*1.1+1.1;
		var vertical = camera.fieldOfView*Math.PI/360, horizontal = Math.atan(Math.tan(vertical)*scene.width/scene.height);
		var distance = Math.max(halfWidth/Math.tan(horizontal),1.8/Math.tan(vertical))*1.35+1;
		camera.near = 0.05; camera.far = distance+60;
		camera.setPosition(distance*0.12,1.6+distance*0.22,distance); camera.lookAt(new Vector3D(0,1.55,0));
	}
	private function updateButtons():Void {
		animationButton.data = "动画：" + (playing ? "播放" : "暂停");
		clipButton.data = "动作：" + (clip == "Walk" ? "行走" : "待机");
		textureButton.data = "多纹理：" + (scene.multiTextureEnabled ? "开启" : "关闭");
		lightButton.data = "光照：" + (lighting ? "开启" : "关闭");
		countButton.data = "角色：" + count + " 个";
		shadowButton.data = "阴影：" + (light.shadowEnabled ? "开启" : "关闭");
		filterButton.data = "过滤：" + (smoothing ? "线性" : "最近点");
		rotateButton.data = "旋转：" + (rotating ? "开启" : "关闭");
	}
}
