package test;

import hx.assets.Assets;
import hx.assets.ModelAsset;
import hx.display3d.Camera3D;
import hx.display.Image;
import hx.display.Label;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import hx.display3d.Node3D;
import hx.display.Scene;
import hx.display.Scene3D;
import hx.events.AnimationEvent3D;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;

/** 只使用 hxmaker API：Assets 加载、动画过渡、骨骼挂点和多纹理对照。 */
class CharacterRender extends Scene {
	private var assets:Assets;
	private var source:ModelAsset;
	private var view:Scene3D;
	private var camera:Camera3D;
	private var pivot:Node3D;
	private var floor:MeshObject;
	private var light:DirectionalLight3D;
	private var models:Array<Model3D> = [];
	private var sockets:Array<Node3D> = [];
	private var props:Array<MeshObject> = [];
	private var propGeometry:Geometry3D;
	private var propMaterial:LambertTextureMaterial;
	private var previews:Array<Image> = [];
	private var buttons:Array<{label:Label, caption:Void->String}> = [];
	private var status:Label;
	private var detail:Label;
	private var eventLabel:Label;
	private var loading:Bool = false;
	private var playing:Bool = true;
	private var clip:String = "Walk";
	private var fadeSeconds:Float = 0.8;
	private var speed:Float = 1;
	private var count:Int = 3;
	private var lighting:Bool = true;
	private var smoothing:Bool = true;
	private var rotating:Bool = false;
	private var mirrored:Bool = false;
	private var socketVisible:Bool = true;
	private var socketSide:String = "R";
	private var dragging:Bool = false;
	private var previousX:Float = 0;
	private var statusTime:Float = 0;
	private var loadVersion:Int = 0;
	private var rapidRemaining:Int = 0;
	private var rapidTime:Float = 0;
	private var rapidWalk:Bool = false;
	private var selectedName:String = "";
	private var lastEvent:String = "等待播放事件";

	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true;
		sceneBackground.data = 0x172033; sceneBackground.alpha = 1;
		label("角色动画过渡与骨骼挂点 · 纯 hxmaker API",24,19,25,0xffffff);
		action(0,() -> "动画：" + (playing ? "播放" : "暂停"),toggleAnimation);
		action(1,() -> "动作：" + clip,function() { clip = clip == "Walk" ? "Idle" : "Walk"; switchAnimations(); });
		action(2,() -> "过渡：" + fadeSeconds + "s",function() { fadeSeconds = fadeSeconds == 0 ? 0.2 : fadeSeconds == 0.2 ? 0.8 : 0; });
		action(3,() -> "速度：" + speed,function() {
			speed = speed == 0 ? 0.5 : speed == 0.5 ? 1 : speed == 1 ? 2 : 0;
			for (model in models) model.animation.speed = speed;
		});
		action(4,() -> "重新加载资源",loadModel);
		action(5,() -> "角色：" + count + " 个",function() { count = count == 1 ? 3 : count == 3 ? 6 : 1; createModels(); });
		action(6,() -> "多纹理：" + (view.multiTextureEnabled ? "开" : "关"),function() { view.multiTextureEnabled = !view.multiTextureEnabled; });
		action(7,() -> "光照：" + (lighting ? "开" : "关"),function() { lighting = !lighting; applyMaterials(); });
		action(8,() -> "阴影：" + (light.shadowEnabled ? "开" : "关"),function() { light.shadowEnabled = !light.shadowEnabled; });
		action(9,() -> "旋转：" + (rotating ? "开" : "关"),function() { rotating = !rotating; });
		action(10,() -> "挂件：" + (socketVisible ? "显示" : "隐藏"),function() { socketVisible = !socketVisible; for (socket in sockets) socket.visible = socketVisible; });
		action(11,() -> "挂点：" + (socketSide == "R" ? "右手" : "左手"),changeSocket);
		action(12,() -> "首个：单次动作",function() { if (models.length > 0) { models[0].animation.play(clip,false); playing = true; } });
		action(13,() -> "定位到 25%",function() { rapidRemaining = 0; for (model in models) model.animation.seek(model.animation.duration*0.25); });
		action(14,() -> "停止／初始姿态",function() { rapidRemaining = 0; for (model in models) model.animation.stop(); playing = false; });
		action(15,() -> "从头循环播放",startAnimations);
		action(16,() -> "首个：连续切换",function() {
			rapidRemaining = 6; rapidTime = 0; playing = true;
			if (models.length > 0) { rapidWalk = models[0].animation.currentName == "Walk"; models[0].animation.resume(); }
		});
		action(17,() -> "首个：" + (mirrored ? "镜像缩放" : "普通缩放"),function() { mirrored = !mirrored; applyMirror(); });
		action(18,() -> "过滤：" + (smoothing ? "线性" : "最近点"),function() { smoothing = !smoothing; applyMaterials(); });
		action(19,() -> "重新取景",fitModels);

		view = new Scene3D(912,400); view.x = 24; view.y = 220;
		view.backgroundColor = 0x24334d; view.backgroundAlpha = 1; view.ambientIntensity = 0.35; addChild(view);
		pivot = new Node3D(); view.root.addChild(pivot);
		camera = new Camera3D(); view.root.addChild(camera); view.camera = camera;
		light = new DirectionalLight3D(0xffffff,0.85); light.direction = new Vector3D(-1,-2,-1);
		light.shadowEnabled = true; view.root.addChild(light); view.light = light;
		floor = new MeshObject(PlaneGeometry.create(30,30),new LambertTextureMaterial(null,0x708299));
		floor.material.cullMode = CullMode3D.NONE; floor.y = -0.02; floor.pickable = false; view.root.addChild(floor);
		status = label("准备加载角色……",24,631,15,0xd7e3fc);
		detail = label("拖动视口旋转；点击动作切换观察过渡。",24,656,14,0xa9bad6);
		eventLabel = label(lastEvent,24,681,14,0xa9bad6);
		label("身体",24,757,12,0xa9bad6); label("面板",112,757,12,0xa9bad6); label("关节",200,757,12,0xa9bad6);
		label("挂件复用关节贴图；连续切换只影响第一个角色。",302,715,14,0xa9bad6);
		label("源图方向：身体左上红标、左下绿标；面板眼睛在上。",302,742,13,0xa9bad6);
		view.addEventListener(MouseEvent.MOUSE_DOWN,function(event:MouseEvent) {
			dragging = true; previousX = event.stageX; rotating = false;
			var hit = view.pick(event.stageX,event.stageY); selectedName = hit == null ? "" : hit.object.name; updateButtons();
		});
		view.addEventListener(MouseEvent.MOUSE_MOVE,function(event:MouseEvent) {
			if (dragging) { pivot.rotationY += (event.stageX-previousX)*0.5; previousX = event.stageX; }
		});
		view.addEventListener(MouseEvent.MOUSE_UP,function(_) { dragging = false; });
		view.addEventListener(MouseEvent.MOUSE_OUT,function(_) { dragging = false; });
		updateButtons(); loadModel();
	}
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (view == null || isDisposed) return;
		if (rapidRemaining > 0 && models.length > 0 && playing) {
			rapidTime += dt;
			if (rapidTime >= 0.08) {
				rapidTime = 0; rapidRemaining--; rapidWalk = !rapidWalk;
				models[0].animation.crossFade(rapidWalk ? "Walk" : "Idle",0.8);
			}
		}
		for (model in models) model.update(dt);
		if (rotating) pivot.rotationY += dt*12;
		statusTime += dt;
		if (!loading && models.length > 0 && statusTime >= 0.2) {
			statusTime = 0;
			var animation = models[0].animation;
			status.data = "主批次：" + view.stats.drawCalls + "　槽位：" + view.stats.textureSlots
				+ "　阴影批次：" + view.stats.shadowDrawCalls + "　首个：" + animation.currentName
				+ " " + Math.round(animation.time*100)/100 + "s　过渡：" + (animation.transitioning ? Math.round(animation.transitionProgress*100)+"%" : "完成");
			detail.data = "可见网格：" + view.stats.visibleMeshes + "　上传：" + Math.round(view.stats.uploadedBytes/1024)
				+ " KiB　阴影：" + view.stats.shadowStatus + (selectedName == "" ? "" : "　选中：" + selectedName);
			eventLabel.data = "首个角色事件：" + lastEvent; updateButtons();
		}
	}
	private function label(text:String,x:Float,y:Float,size:Int,color:Int):Label {
		var result = new Label(text); result.x = x; result.y = y; result.fontSize = size; result.color = color; addChild(result); return result;
	}
	private function action(index:Int,caption:Void->String,callback:Void->Void):Void {
		var result = label("",24+(index%5)*185,67+Std.int(index/5)*36,16,0x8ed6ff);
		buttons.push({label:result,caption:caption});
		result.addEventListener(MouseEvent.CLICK,function(_) { callback(); updateButtons(); });
	}
	private function updateButtons():Void { for (button in buttons) button.label.data = button.caption(); }
	private function recordEvent(event:AnimationEvent3D):Void {
		lastEvent = event.type + " / " + event.clipName + " / " + Math.round(event.time*100)/100 + "s"
			+ (event.loopCount > 0 ? " / 跨越 " + event.loopCount + " 轮" : "");
	}
	private function disposeModels():Void {
		rapidRemaining = 0;
		for (model in models) model.dispose();
		// 实例化或挂接中途失败时，部分道具可能尚未进入模型树。
		for (prop in props) prop.dispose();
		models = []; sockets = []; props = [];
		if (propGeometry != null) { propGeometry.dispose(); propGeometry = null; }
		if (propMaterial != null) { propMaterial.dispose(); propMaterial = null; }
	}
	private function disposePreviews():Void {
		for (image in previews) { removeChild(image); image.data = null; image.dispose(); }
		previews = [];
	}
	private function loadModel():Void {
		if (loading || isDisposed) return;
		loading = true; dragging = false; source = null; selectedName = ""; lastEvent = "等待加载";
		disposeModels(); disposePreviews();
		if (assets != null) { assets.stop(); assets.clean(); }
		var request = new Assets(), version = ++loadVersion; assets = request; request.tryLoadTimes = 0;
		status.color = 0xd7e3fc; status.data = "加载进度：0%";
		detail.data = "通过 Assets 加载 robot.glb 及内嵌 PNG。";
		request.loadModel("assets/robot.glb");
		request.onProgress(value -> { if (!isDisposed && version == loadVersion) status.data = "加载进度：" + Math.round(value*100) + "%"; });
		request.onError(error -> {
			if (isDisposed || version != loadVersion) { request.clean(); return; }
			loading = false; request.stop(); request.clean(); status.color = 0xff9b91; status.data = "角色加载失败"; detail.data = error.error;
		});
		request.onComplete(_ -> {
			// stop 不取消已发出的请求，迟到的结果仍需解除资源引用。
			if (isDisposed || version != loadVersion) { request.clean(); return; }
			try {
				source = request.getModel("robot");
				#if hxmaker_character_checks
				CharacterChecks.run(source);
				AnimationSocketChecks.run(source);
				#end
				createModels();
				for (i in 0...source.textureCount) {
					var image = new Image(source.getTexture(i)); image.width = image.height = 44; image.x = 24+i*88; image.y = 708;
					addChild(image); previews.push(image);
				}
				for (warning in source.warnings) trace("GLB 提示：" + warning);
				status.data = "加载完成：3 张贴图、动画过渡、手部挂点";
			} catch (error:Dynamic) {
				disposeModels(); disposePreviews(); source = null; request.clean();
				status.color = 0xff9b91; status.data = "角色实例化失败"; detail.data = Std.string(error); trace(Std.string(error));
			}
			loading = false; updateButtons();
		});
		request.start();
	}
	private function createModels():Void {
		if (source == null) return;
		disposeModels(); selectedName = "";
		propGeometry = BoxGeometry.create(0.18,0.9,0.18);
		propMaterial = new LambertTextureMaterial(source.getTexture(2)); propMaterial.cullMode = CullMode3D.NONE; propMaterial.colorMultiplyLinear = true;
		for (i in 0...count) {
			var model = source.createInstance(-1,{lightingEnabled:lighting}); models.push(model); pivot.addChild(model);
			model.x = (i-(count-1)/2)*2.2;
			for (mesh in model.meshes) mesh.castShadow = true;
			var prop = new MeshObject(propGeometry,propMaterial); prop.name = "手持道具 " + (i+1); prop.castShadow = true; props.push(prop);
			if (i == 0) for (type in [AnimationEvent3D.START,AnimationEvent3D.LOOP,AnimationEvent3D.COMPLETE,AnimationEvent3D.FADE_COMPLETE])
				model.animation.addEventListener(type,recordEvent);
		}
		attachProps(); applyMirror(); applyMaterials(); startAnimations(); fitModels();
	}
	private function attachProps():Void {
		for (i in 0...models.length) {
			var model = models[i], nodes = model.findNodes("Wrist." + socketSide);
			if (nodes.length != 1) throw "角色需要唯一的 Wrist." + socketSide + " 骨骼节点";
			var socket = model.createSocket(model.getNodeIndex(nodes[0]),"道具挂点");
			socket.setPosition(0,-0.12,0.08); socket.visible = socketVisible; socket.addChild(props[i]);
			if (i < sockets.length) sockets[i].dispose();
			if (i < sockets.length) sockets[i] = socket; else sockets.push(socket);
		}
	}
	private function changeSocket():Void { socketSide = socketSide == "R" ? "L" : "R"; attachProps(); }
	private function applyMirror():Void {
		for (i in 0...models.length) models[i].setScale(i == 0 && mirrored ? -1.2 : 1,i == 0 && mirrored ? 1.2 : 1,i == 0 && mirrored ? 1.2 : 1);
	}
	private function startAnimations():Void {
		rapidRemaining = 0; playing = true;
		for (i in 0...models.length) {
			var animation = models[i].animation; animation.speed = speed; animation.play(clip,true);
			animation.seek(animation.duration*i/Math.max(1,models.length));
		}
	}
	private function switchAnimations():Void {
		rapidRemaining = 0;
		for (model in models) { model.animation.crossFade(clip,fadeSeconds,true); if (!playing) model.animation.pause(); }
	}
	private function toggleAnimation():Void {
		playing = !playing;
		for (model in models) {
			if (!playing) model.animation.pause();
			else if (model.animation.currentName == null) model.animation.play(clip); else model.animation.resume();
		}
	}
	private function applyMaterials():Void {
		for (model in models) for (mesh in model.meshes) {
			mesh.material.lightingEnabled = lighting; mesh.material.smoothing = smoothing; mesh.material.textureMinSmoothing = null;
		}
		if (propMaterial != null) { propMaterial.lightingEnabled = lighting; propMaterial.smoothing = smoothing; propMaterial.textureMinSmoothing = null; }
		floor.material.lightingEnabled = lighting; floor.material.smoothing = smoothing;
	}
	private function fitModels():Void {
		if (models.length == 0) return;
		pivot.rotationY = 0;
		var halfWidth = (models.length-1)*1.1+1.4;
		var vertical = camera.fieldOfView*Math.PI/360, horizontal = Math.atan(Math.tan(vertical)*view.width/view.height);
		var distance = Math.max(halfWidth/Math.tan(horizontal),2/Math.tan(vertical))*1.35+1;
		camera.near = 0.05; camera.far = distance+60;
		camera.setPosition(distance*0.12,1.6+distance*0.22,distance); camera.lookAt(new Vector3D(0,1.55,0));
	}
	override public function onRemoveToStage():Void { dragging = false; super.onRemoveToStage(); }
	override public function dispose():Void {
		if (isDisposed) return;
		loadVersion++; loading = false; dragging = false;
		if (assets != null) assets.stop();
		disposeModels(); disposePreviews();
		var floorGeometry = floor == null ? null : floor.geometry, floorMaterial = floor == null ? null : floor.material;
		super.dispose();
		if (floorGeometry != null) floorGeometry.dispose();
		if (floorMaterial != null) floorMaterial.dispose();
		if (assets != null) { assets.clean(); assets = null; }
		source = null;
	}
}
