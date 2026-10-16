package test;

import hx.assets.Assets;
import hx.collision3d.BoxCollider3D;
import hx.collision3d.Collider3D;
import hx.collision3d.RampCollider3D;
import hx.collision3d.CollisionWorld3D;
import hx.controls3d.CharacterController3D;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Camera3D;
import hx.display.Label;
import hx.display.MeshObject;
import hx.display.Model3D;
import hx.display.Scene;
import hx.display.Scene3D;
import hx.display.Stage;
import hx.events.Event;
import hx.events.Keyboard;
import hx.events.KeyboardEvent;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.RampGeometry;
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;
import hx.material.Material3D;

/** 纯 hxmaker 验收场景；更新顺序为控制器、角色动画、相机，不修改原有输入语义。 */
class TerrainCharacterScene extends Scene {
	private var view:Scene3D;
	private var cameraControl:OrbitCameraController3D;
	private var input:Scene3DInput;
	private var world:CollisionWorld3D = new CollisionWorld3D();
	private var colliders:Array<Collider3D> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var model:Model3D;
	private var controller:CharacterController3D;
	private var assets:Assets;
	private var goal:Vector3D;
	private var status:Label;
	private var detail:Label;
	private var maskLabel:Label;
	private var marker:MeshObject;
	private var mask:Int = 1;
	private var stepsEnabled:Bool = true;
	private var slopeLimit:Float = 45;
	private var slopeLabel:Label;
	private var elapsed:Float = 0;
	private var keys:Map<Int,Bool> = [];
	private var inputStage:Stage;
	private var lastAction:String = "资源加载中……";
	private var updates:Int = 0;
	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true; sceneBackground.data = 0x172033; sceneBackground.alpha = 1;
		label("台阶与坡面 · 跨步 / 贴地 / 坡度限制",24,18,25,0xffffff);
		action("上台阶",24,65,function() { scenario(new Vector3D(-10,0,-6),new Vector3D(-10,1.6,2.2)); });
		action("下台阶",210,65,function() { scenario(new Vector3D(-10,1.602,2.2),new Vector3D(-10,0,-6)); });
		action("矮顶棚",390,65,function() { scenario(new Vector3D(-5,0,-7),new Vector3D(-5,0.4,-2)); });
		action("过高台阶",570,65,function() { scenario(new Vector3D(-5,0,0),new Vector3D(-5,0.85,4.5)); });
		action("上缓坡",790,65,function() { scenario(new Vector3D(1,0,-7),new Vector3D(1,2.2,2)); });
		action("下缓坡",24,105,function() { scenario(new Vector3D(1,2.202,2),new Vector3D(1,0,-7)); });
		action("陡坡限制",210,105,function() { scenario(new Vector3D(7,0,-7),new Vector3D(7,3.2,-2)); });
		action("旋转坡道",400,105,function() { scenario(new Vector3D(4.5,0,5),new Vector3D(12.5,1.8,5)); });
		maskLabel = action("跨步：开",640,105,function() { stepsEnabled = !stepsEnabled; if (controller != null) controller.stepOffset = stepsEnabled ? 0.45 : 0; maskLabel.data = stepsEnabled ? "跨步：开" : "跨步：关"; });
		slopeLabel = action("坡度：45°",850,105,function() { slopeLimit = slopeLimit == 45 ? 65 : 45; if (controller != null) controller.maxSlopeAngle = slopeLimit; slopeLabel.data = "坡度："+slopeLimit+"°"; });
		view = new Scene3D(1072,490); view.x = 24; view.y = 150; view.backgroundColor = 0x26384c; view.backgroundAlpha = 1;
		view.ambientIntensity = 0.4; view.profilingEnabled = true; addChild(view);
		var camera = new Camera3D(); view.root.addChild(camera); view.camera = camera;
		var light = new DirectionalLight3D(0xffffff,0.8); light.direction = new Vector3D(-1,-2,-1); light.shadowEnabled = true; view.root.addChild(light); view.light = light;
		cameraControl = new OrbitCameraController3D(camera,new Vector3D(0,1.2,0)); cameraControl.yaw = 15; cameraControl.pitch = 50; cameraControl.distance = 33; cameraControl.minPitch = 10; cameraControl.maxDistance = 45; cameraControl.snap();
		input = new Scene3DInput(view,cameraControl); input.addEventListener(Scene3DInputEvent.SELECT,onSelect);
		box("地面",36,1,28,0,-0.5,0,0x637c89);
		for (i in 0...4) box("台阶 "+(i+1),3,(i+1)*0.4,1.2,-10,(i+1)*0.2,-3.4+i*1.2,0xb89465);
		box("楼梯平台",3,1.6,2,-10,0.8,1.8,0xb89465);
		box("顶棚下台阶",3,0.4,2,-5,0.2,-3,0xc57869);
		box("矮顶棚",3,0.2,4,-5,2.3,-4,0xb49acc);
		box("过高台阶",3,0.85,2,-5,0.425,4,0xc57869);
		ramp("缓坡",3,2.2,6,1,0,-2,0,0x71aa83);
		box("缓坡平台",3,2.2,2,1,1.1,2,0x71aa83);
		ramp("陡坡",3,3.2,2,7,0,-4,0,0xcd9668);
		box("陡坡平台",3,3.2,2,7,1.6,-2,0xcd9668);
		ramp("旋转坡道",3,1.8,5,9,0,5,90,0x6e99c4);
		box("旋转坡道平台",2,1.8,3,12.5,0.9,5,0x6e99c4);
		marker = visual(0.4,0.025,0.4,0xffda61); marker.visible = false;
		status = label("通过 Assets 加载带贴图角色……",24,656,15,0xd7e3fc);
		detail = label("",24,688,14,0xa9bad6);
		label("WASD／方向键：移动；空格：起跳；Esc：停止目标；轻点地面设置目标；左键拖动与滚轮：镜头。",24,720,14,0xa9bad6);
		label("楼梯每级 0.4，跨步 0.45；绿坡约 20°，橙坡约 58°，蓝坡旋转 90°。顶部按钮均只指定目标。",24,751,14,0xa9bad6);
		inputStage = stage; inputStage.addEventListener(Event.DEACTIVATE,onDeactivate);
		inputStage.addEventListener(KeyboardEvent.KEY_DOWN,onKeyDown); inputStage.addEventListener(KeyboardEvent.KEY_UP,onKeyUp);
		view.addEventListener(KeyboardEvent.KEY_DOWN,onKeyDown); view.addEventListener(KeyboardEvent.KEY_UP,onKeyUp); stage.focus = view;
		view.addEventListener(Event.FOCUS_OUT,onDeactivate);
		#if hxmaker_terrain_checks
		CollisionChecks.run(); TerrainChecks.run();
		#end
		load();
	}
	private function label(text:String,x:Float,y:Float,size:Int,color:Int):Label {
		var value = new Label(text); value.x = x; value.y = y; value.fontSize = size; value.color = color; value.mouseEnabled = false; addChild(value); return value;
	}
	private function action(text:String,x:Float,y:Float,callback:Void->Void):Label {
		var value = label(text,x,y,17,0x8ed6ff); value.mouseEnabled = true;
		value.addEventListener(MouseEvent.CLICK,function(event:MouseEvent) { callback(); if (view != null) stage.focus = view; event.preventDefault(); }); return value;
	}
	private function visual(width:Float,height:Float,depth:Float,color:Int):MeshObject {
		var geometry = BoxGeometry.create(width,height,depth), material = new LambertTextureMaterial(null,color); material.cullMode = CullMode3D.NONE;
		geometries.push(geometry); materials.push(material); var mesh = new MeshObject(geometry,material); mesh.pickable = false; mesh.castShadow = true; view.root.addChild(mesh); return mesh;
	}
	private function box(name:String,width:Float,height:Float,depth:Float,x:Float,y:Float,z:Float,color:Int,layer:Int = 1):Void {
		var mesh = visual(width,height,depth,color); mesh.name = name; mesh.setPosition(x,y,z);
		var collider = new BoxCollider3D(width,height,depth,mesh); collider.name = name; collider.layer = layer; colliders.push(collider); world.add(collider);
	}
	private function load():Void {
		var request = new Assets(); assets = request; request.tryLoadTimes = 0;
		request.loadGlb("assets/robot.glb");
		request.onError(error -> { request.stop(); request.clean(); if (!isDisposed) { status.data = "加载失败："+error.error+"；可点击底部重新进入"; trace(status.data); } });
		request.onComplete(_ -> {
			if (isDisposed) { request.clean(); return; }
			try {
				var source = request.getGlb("robot"); if (source == null || !source.texturesReady) throw "GLB 或贴图未准备好";
				model = source.createInstance(-1,{lightingEnabled:true}); model.setScale(0.6,0.6,0.6); view.root.addChild(model);
				for (mesh in model.meshes) mesh.castShadow = true; model.animation.play("Idle");
				controller = new CharacterController3D(world,model,0.35,1.9); controller.collisionMask = mask; controller.stepOffset = stepsEnabled ? 0.45 : 0; controller.maxSlopeAngle = slopeLimit; controller.groundSnapDistance = 0.45; reset(new Vector3D(-10,0,-6));
			} catch (error:Dynamic) {
				if (controller != null) { controller.dispose(); controller = null; } if (model != null) { model.dispose(); model = null; }
				request.clean(); status.data = "创建失败："+Std.string(error); trace(status.data);
			}
		});
		request.start();
	}
	private function reset(point:Vector3D):Void {
		if (controller == null) return;
		keys = []; goal = null; controller.teleport(point); lastAction = "脚底位置已设为 ("+point.x+", "+point.y+", "+point.z+")";
	}
	private function scenario(start:Vector3D,target:Vector3D):Void { if (controller == null) return; reset(start); goal = target; }
	private function ramp(name:String,width:Float,height:Float,depth:Float,x:Float,y:Float,z:Float,yaw:Float,color:Int):Void {
		var geometry = RampGeometry.create(width,height,depth), material = new LambertTextureMaterial(null,color); material.cullMode = CullMode3D.NONE;
		geometries.push(geometry); materials.push(material); var mesh = new MeshObject(geometry,material); mesh.name = name; mesh.pickable = false; mesh.castShadow = true;
		mesh.setPosition(x,y,z); mesh.rotationY = yaw; view.root.addChild(mesh);
		var collider = new RampCollider3D(width,height,depth,mesh); collider.name = name; colliders.push(collider); world.add(collider);
	}
	private function onSelect(event:Scene3DInputEvent):Void {
		if (controller == null) return;
		var hit = world.raycast(event.ray,100,1);
		if (hit == null || hit.surfaceNormal.y <= 0) { lastAction = "请轻点地面或坡面；目标不代表角色一定能爬过该处坡度"; return; }
		goal = hit.point.clone(); lastAction = "目标 X/Z："+round(goal.x)+" / "+round(goal.z);
	}
	private function onKeyDown(event:KeyboardEvent):Void {
		if (event.keyCode == Keyboard.ESCAPE) { keys = []; goal = null; lastAction = "已停止目标移动，可观察坡面站立"; return; }
		if (event.keyCode == Keyboard.SPACE && !keys.exists(Keyboard.SPACE) && controller != null) controller.jump(6);
		keys.set(event.keyCode,true);
	}
	private function onKeyUp(event:KeyboardEvent):Void { keys.remove(event.keyCode); }
	private function onDeactivate(event:Event):Void { keys = []; }
	private function held(a:Int,b:Int):Bool { return keys.exists(a) || keys.exists(b); }
	private function round(value:Float):Float { return Math.round(value*100)/100; }
	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt); if (isDisposed || view == null) return;
		if (controller != null && dt > 0) {
			var vx = (held(Keyboard.D,Keyboard.RIGHT) ? 1 : 0)-(held(Keyboard.A,Keyboard.LEFT) ? 1 : 0);
			var vz = (held(Keyboard.S,Keyboard.DOWN) ? 1 : 0)-(held(Keyboard.W,Keyboard.UP) ? 1 : 0);
			var velocity = new Vector3D(vx,0,vz);
			if (velocity.length > 0) { goal = null; velocity.normalize(); velocity.scaleBy(3); }
			else if (goal != null) {
				var position = controller.position; velocity.setTo(goal.x-position.x,0,goal.z-position.z); var distance = velocity.length;
				if (distance < 0.05) { goal = null; velocity.setTo(0,0,0); }
				else { velocity.normalize(); velocity.scaleBy(Math.min(3,distance/dt)); }
			}
			var result = controller.update(dt,velocity); updates++;
			var moved = Math.sqrt(result.displacement.x*result.displacement.x+result.displacement.z*result.displacement.z);
			if (velocity.length > 0) model.rotationY = Math.atan2(velocity.x,velocity.z)*180/Math.PI;
			var clip = moved > 1e-5 ? "Walk" : "Idle"; if (model.animation.currentName != clip) model.animation.crossFade(clip,0.2); model.update(dt);
			marker.visible = goal != null; if (goal != null) marker.setPosition(goal.x,goal.y+0.02,goal.z);
			elapsed += dt;
			if (elapsed >= 0.15) {
				elapsed = 0; var p = controller.position;
				status.data = "脚底 "+round(p.x)+" / "+round(p.y)+" / "+round(p.z)+"　grounded="+controller.grounded+"　垂直速度="+round(controller.verticalVelocity)
					+"　跨步="+result.stepped+"　限坡="+result.slopeLimited+"　stuck="+result.stuck;
				detail.data = lastAction+"　支撑法线 Y="+(result.groundNormal == null ? "无" : Std.string(round(result.groundNormal.y)));
			}
		}
		cameraControl.update(dt);
	}
	override public function dispose():Void {
		if (isDisposed) return;
		if (inputStage != null) {
			inputStage.removeEventListener(Event.DEACTIVATE,onDeactivate); inputStage.removeEventListener(KeyboardEvent.KEY_DOWN,onKeyDown); inputStage.removeEventListener(KeyboardEvent.KEY_UP,onKeyUp);
		}
		if (input != null) input.dispose(); if (cameraControl != null) cameraControl.dispose(); if (controller != null) controller.dispose();
		for (collider in colliders) collider.dispose(); world.dispose();
		if (model != null) model.dispose();
		super.dispose();
		var geometryReferences = 0, materialReferences = 0;
		for (geometry in geometries) geometryReferences += geometry.referenceCount;
		for (material in materials) materialReferences += material.referenceCount;
		for (geometry in geometries) geometry.dispose(); for (material in materials) material.dispose();
		if (assets != null) { assets.stop(); assets.clean(); }
		trace("HXMAKER_TERRAIN_RELEASE "+haxe.Json.stringify({worldDisposed:world.isDisposed,colliders:world.colliders.length,updates:updates,
			controllerDisposed:controller == null || controller.isDisposed,inputDisposed:input == null || input.isDisposed,
			geometryReferences:geometryReferences,materialReferences:materialReferences}));
		colliders = []; geometries = []; materials = []; keys = []; goal = null; inputStage = null;
	}
}
