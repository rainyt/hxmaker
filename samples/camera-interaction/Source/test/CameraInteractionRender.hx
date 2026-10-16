package test;

import hx.assets.Assets;
import hx.controls3d.FollowCameraController3D;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Camera3D;
import hx.display.Label;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Scene;
import hx.display.Scene3D;
import hx.display.Sprite;
import hx.display.Quad;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;
import hx.material.Material3D;

/** 相机控制与查询的独立示例；显示、资源、输入全部经 hxmaker API。 */
class CameraInteractionRender extends Scene {
	private var assets:Assets;
	private var view:Scene3D;
	private var sideView:Scene3D;
	private var orbit:OrbitCameraController3D;
	private var follow:FollowCameraController3D;
	private var sideOrbit:OrbitCameraController3D;
	private var input:Scene3DInput;
	private var sideInput:Scene3DInput;
	private var light:DirectionalLight3D;
	private var models:Array<Model3D> = [];
	private var sideModel:Model3D;
	private var goals:Array<Vector3D> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var selected:Int = 1;
	private var followMode:Bool = false;
	private var transformed:Bool = false;
	private var paused:Bool = false;
	private var autoMove:Bool = false;
	private var waypoint:Int = 0;
	private var loading:Bool = false;
	private var loadVersion:Int = 0;
	private var uiClicks:Int = 0;
	private var lastHit:String = "点击角色选择；点击空白地面移动所选角色。";
	private var lastSide:String = "右侧视口独立接收拖动与滚轮。";
	private var status:Label;
	private var detail:Label;
	private var sideStatus:Label;
	private var uiStatus:Label;
	private var buttons:Array<{label:Label,caption:Void->String}> = [];
	private var marker:MeshObject;
	private var goalMarker:MeshObject;
	private var statusTime:Float = 0;

	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true; sceneBackground.data = 0x172033; sceneBackground.alpha = 1;
		label("相机与三维交互 · 环绕 / 跟随 / 射线查询",24,20,25,0xffffff);
		action(0,() -> "相机："+(followMode ? "跟随" : "环绕"),switchCamera);
		action(1,() -> "下一个角色",function() { selectModel((selected+1)%3); });
		action(2,() -> "拉近",function() { input.controller.zoomBy(0.8); });
		action(3,() -> "拉远",function() { input.controller.zoomBy(1.25); });
		action(4,() -> "重新取景",resetCamera);
		action(5,() -> "多纹理："+(view.multiTextureEnabled ? "开" : "关"),function() { view.multiTextureEnabled = !view.multiTextureEnabled; sideView.multiTextureEnabled = view.multiTextureEnabled; });
		action(6,() -> "阴影："+(light.shadowEnabled ? "开" : "关"),function() { light.shadowEnabled = !light.shadowEnabled; });
		action(7,() -> "自动移动："+(autoMove ? "开" : "关"),function() {
			autoMove = !autoMove;
			if (!autoMove && selected < goals.length) goals[selected] = null;
		});
		action(8,() -> "视口变换："+(transformed ? "开" : "关"),function() {
			transformed = !transformed; input.cancel("viewportChanged"); view.scaleX = view.scaleY = transformed ? 0.92 : 1; view.rotation = transformed ? 3 : 0;
		});
		action(9,() -> "重新加载资源",loadModel);
		view = makeView(800,480,24,152); sideView = makeView(248,240,848,152);
		light = view.light; light.shadowEnabled = true;
		orbit = new OrbitCameraController3D(view.camera,new Vector3D(0,1.5,0)); orbit.maxDistance = 40; orbit.minPitch = 5;
		follow = new FollowCameraController3D(view.camera); follow.maxDistance = 40; follow.minPitch = 5;
		sideOrbit = new OrbitCameraController3D(sideView.camera,new Vector3D(0,1.5,0)); sideOrbit.distance = 6; sideOrbit.pitch = 15; sideOrbit.maxDistance = 15; sideOrbit.minPitch = 5; sideOrbit.snap();
		input = new Scene3DInput(view,orbit); input.maxDistance = 150;
		sideInput = new Scene3DInput(sideView,sideOrbit);
		input.addEventListener(Scene3DInputEvent.SELECT,onSelect);
		sideInput.addEventListener(Scene3DInputEvent.SELECT,function(event:Scene3DInputEvent) {
			lastSide = event.hit == null ? "侧视图：没有命中" : "侧视图命中："+event.hit.object.name;
		});
		marker = ownedBox(view,1.15,0.025,0.9,0xffda61); marker.pickable = false; marker.y = 0.01; marker.visible = false;
		goalMarker = ownedBox(view,0.4,0.03,0.4,0xff7868); goalMarker.pickable = false; goalMarker.visible = false; goalMarker.y = 0.02;
		buildOverlay();
		label("独立视口：拖动／滚轮缩放",848,409,14,0xd7e3fc);
		sideStatus = label(lastSide,848,437,12,0xa9bad6);
		label("点击角色：切换选择",848,476,14,0xa9bad6);
		label("点击地面：设置移动目标",848,503,14,0xa9bad6);
		label("拖动超过 5 像素：旋转相机",848,530,13,0xa9bad6);
		var pause = label("暂停／继续角色移动与动画",848,573,14,0x8ed6ff); pause.mouseEnabled = true;
		pause.addEventListener(MouseEvent.CLICK,function(_) { paused = !paused; });
		var cancel = label("取消当前拖动",848,605,14,0x8ed6ff); cancel.mouseEnabled = true;
		cancel.addEventListener(MouseEvent.CLICK,function(_) { input.cancel(); sideInput.cancel(); });
		status = label("准备加载……",24,652,15,0xd7e3fc);
		detail = label(lastHit,24,681,14,0xa9bad6);
		uiStatus = label("遮挡 UI 点击：0",24,713,14,0xa9bad6);
		label("角色移动 → 动画与蒙皮 → 相机更新；保持原帧调度与多纹理合批。",24,746,14,0xa9bad6);
		resetCamera(); updateButtons(); loadModel();
	}
	private function makeView(width:Float,height:Float,x:Float,y:Float):Scene3D {
		var result = new Scene3D(width,height); result.x = x; result.y = y; result.backgroundColor = 0x24334d; result.backgroundAlpha = 1; result.ambientIntensity = 0.35; addChild(result);
		var camera = new Camera3D(); result.root.addChild(camera); result.camera = camera;
		var light = new DirectionalLight3D(0xffffff,0.85); light.direction = new Vector3D(-1,-2,-1); result.root.addChild(light); result.light = light;
		var geometry = PlaneGeometry.create(24,24), material = new LambertTextureMaterial(null,0x667d93);
		geometries.push(geometry); materials.push(material); material.cullMode = CullMode3D.NONE;
		var floor = new MeshObject(geometry,material); floor.y = -0.025; floor.pickable = false; result.root.addChild(floor);
		return result;
	}
	private function ownedBox(view:Scene3D,width:Float,height:Float,depth:Float,color:Int):MeshObject {
		var geometry = BoxGeometry.create(width,height,depth), material = new LambertTextureMaterial(null,color);
		geometries.push(geometry); materials.push(material);
		var mesh = new MeshObject(geometry,material); view.root.addChild(mesh); return mesh;
	}
	private function buildOverlay():Void {
		var box = new Sprite(); box.x = 48; box.y = 176; box.mouseChildren = false;
		box.addChild(new Quad(272,38,0x354c71));
		var text = new Label("二维 UI：点击不穿透到角色"); text.fontSize = 16; text.color = 0xffffff; text.x = 10; text.y = 8; box.addChild(text); addChild(box);
		for (type in [MouseEvent.MOUSE_DOWN,MouseEvent.MOUSE_MOVE,MouseEvent.MOUSE_UP]) box.addEventListener(type,function(event:MouseEvent) { event.preventDefault(); });
		box.addEventListener(MouseEvent.CLICK,function(event:MouseEvent) { uiClicks++; event.preventDefault(); });
	}
	private function label(text:String,x:Float,y:Float,size:Int,color:Int):Label {
		var value = new Label(text); value.x = x; value.y = y; value.fontSize = size; value.color = color; value.mouseEnabled = false; addChild(value); return value;
	}
	private function action(index:Int,caption:Void->String,callback:Void->Void):Void {
		var value = label("",24+(index%5)*216,67+Std.int(index/5)*36,16,0x8ed6ff); value.mouseEnabled = true;
		buttons.push({label:value,caption:caption}); value.addEventListener(MouseEvent.CLICK,function(_) { callback(); updateButtons(); });
	}
	private function updateButtons():Void { for (button in buttons) button.label.data = button.caption(); }
	private function switchCamera():Void {
		input.cancel("cameraChanged"); followMode = !followMode;
		if (followMode) { follow.syncFromCamera(); input.controller = follow; } else { orbit.syncFromCamera(); input.controller = orbit; }
	}
	private function resetCamera():Void {
		if (orbit == null) return;
		orbit.target.setTo(0,1.5,0); orbit.yaw = 12; orbit.pitch = 25; orbit.distance = 16;
		follow.yaw = 12; follow.pitch = 22; follow.distance = 9;
		if (followMode && follow.targetNode != null) follow.snap(); else orbit.snap();
	}
	private function selectModel(index:Int):Void {
		if (index < 0 || index >= models.length) return;
		selected = index; follow.targetNode = models[selected]; lastHit = "已选择角色 "+(selected+1);
	}
	private function onSelect(event:Scene3DInputEvent):Void {
		if (models.length == 0) return;
		if (event.hit != null && event.hit.model != null) {
			var index = models.indexOf(event.hit.model);
			if (index >= 0) { selectModel(index); lastHit += " / "+event.hit.object.name+" / 三角形 "+event.hit.triangleIndex; }
			return;
		}
		var distance = event.ray.intersectPlane(new Vector3D(0,1,0),0,150);
		if (distance == null) { lastHit = "射线未命中前方地面"; return; }
		var point = event.ray.at(distance);
		if (Math.abs(point.x) > 10 || Math.abs(point.z) > 10) { lastHit = "移动目标超出示例地面范围"; return; }
		autoMove = false; goals[selected] = point; lastHit = "角色 "+(selected+1)+" 移动到 ("+Math.round(point.x*10)/10+", "+Math.round(point.z*10)/10+")"; updateButtons();
	}
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (view == null || isDisposed) return;
		if (!paused) {
			if (autoMove && selected < models.length && goals[selected] == null) {
				var points = [new Vector3D(-4,0,-3),new Vector3D(4,0,-3),new Vector3D(4,0,3),new Vector3D(-4,0,3)];
				goals[selected] = points[waypoint++%4];
			}
			for (i in 0...models.length) {
				var model = models[i], goal = goals[i];
				if (goal != null) {
					var dx = goal.x-model.x, dz = goal.z-model.z, length = Math.sqrt(dx*dx+dz*dz), step = Math.min(length,dt*1.8);
					if (length > 1e-5) { model.x += dx/length*step; model.z += dz/length*step; model.rotationY = Math.atan2(dx,dz)*180/Math.PI; }
					if (length <= step+1e-5) goals[i] = null;
				}
				var clip = goals[i] == null ? "Idle" : "Walk";
				if (model.animation.currentName != clip) model.animation.crossFade(clip,0.2);
				model.update(dt);
			}
			if (sideModel != null) sideModel.update(dt);
		}
		if (selected < models.length) {
			marker.visible = true; marker.x = models[selected].x; marker.z = models[selected].z;
			var goal = goals[selected]; goalMarker.visible = goal != null;
			if (goal != null) { goalMarker.x = goal.x; goalMarker.z = goal.z; }
		}
		if (followMode && follow.targetNode != null) follow.update(dt); else orbit.update(dt);
		sideOrbit.update(dt);
		statusTime += dt;
		if (statusTime >= 0.2) {
			statusTime = 0;
			if (!loading && models.length > 0) status.data = "选中："+(selected+1)+"　角色："+(paused ? "暂停" : "运行")+"　主批次："+view.stats.drawCalls+"　槽位："+view.stats.textureSlots
				+"　侧视图批次："+sideView.stats.drawCalls;
			detail.data = lastHit; sideStatus.data = lastSide;
			uiStatus.data = "遮挡 UI 点击："+uiClicks+"　主视口捕获："+input.capturing+"　拖动："+input.dragging+"　侧视口捕获："+sideInput.capturing;
			updateButtons();
		}
	}
	private function clearModels():Void {
		if (follow != null) follow.targetNode = null;
		for (model in models) model.dispose(); models = []; goals = [];
		if (sideModel != null) { sideModel.dispose(); sideModel = null; }
		for (geometry in propGeometries) geometry.dispose(); propGeometries = [];
		if (marker != null) marker.visible = false; if (goalMarker != null) goalMarker.visible = false;
	}
	private function loadModel():Void {
		if (loading || isDisposed) return;
		loading = true; var version = ++loadVersion;
		input.cancel("reload"); sideInput.cancel("reload"); clearModels();
		if (assets != null) { assets.stop(); assets.clean(); }
		var request = new Assets(); assets = request; request.tryLoadTimes = 0; status.color = 0xd7e3fc; status.data = "通过 Assets 加载角色……";
		request.loadGlb("assets/robot.glb");
		request.onError(error -> {
			request.stop(); request.clean(); if (isDisposed || version != loadVersion) return;
			loading = false; status.color = 0xff9b91; status.data = "加载失败："+error.error;
		});
		request.onComplete(_ -> {
			if (isDisposed || version != loadVersion) { request.clean(); return; }
			try {
				var source = request.getGlb("robot");
				#if hxmaker_camera_checks
				CameraInteractionChecks.run(source);
				#end
				for (i in 0...3) {
					var model = source.createInstance(-1,{lightingEnabled:true}); models.push(model); goals.push(null); view.root.addChild(model);
					model.name = "角色 "+(i+1); model.x = (i-1)*3; model.animation.play("Idle"); model.animation.seek(i*0.3);
					for (mesh in model.meshes) mesh.castShadow = true;
					var bone = model.findNodes("Wrist.R")[0], socket = model.createSocket(model.getNodeIndex(bone),"weapon");
					var prop = new MeshObject(ownedPropGeometry(),model.meshes[0].material); prop.name = "手持附件"; prop.y = -0.2; prop.castShadow = true; socket.addChild(prop);
				}
				sideModel = source.createInstance(-1,{lightingEnabled:true}); sideView.root.addChild(sideModel); sideModel.animation.play("Walk");
				selectModel(1); resetCamera(); status.data = "加载完成：两个独立视口";
			} catch (error:Dynamic) {
				clearModels(); request.clean(); status.color = 0xff9b91; status.data = "创建失败："+Std.string(error); trace(Std.string(error));
			}
			loading = false;
		});
		request.start();
	}
	private var propGeometries:Array<Geometry3D> = [];
	private function ownedPropGeometry():Geometry3D { var geometry = BoxGeometry.create(0.12,0.65,0.12); propGeometries.push(geometry); return geometry; }
	override public function dispose():Void {
		if (isDisposed) return;
		loadVersion++; if (assets != null) assets.stop();
		if (input != null) input.dispose(); if (sideInput != null) sideInput.dispose();
		clearModels(); if (orbit != null) orbit.dispose(); if (follow != null) follow.dispose(); if (sideOrbit != null) sideOrbit.dispose();
		super.dispose();
		for (geometry in geometries) geometry.dispose(); for (material in materials) material.dispose();
		if (assets != null) { assets.clean(); assets = null; }
	}
}
