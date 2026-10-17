package test;

import hx.assets.Assets;
import hx.collision3d.BoxCollider3D;
import hx.collision3d.CollisionWorld3D;
import hx.controls3d.CharacterController3D;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display3d.Camera3D;
import hx.display.Label;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
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
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;
import hx.material.Material3D;

/** 纯 hxmaker 验收场景；更新顺序为控制器、角色动画、相机，不修改原有输入语义。 */
class CollisionCharacterScene extends Scene {
	private var view:Scene3D;
	private var cameraControl:OrbitCameraController3D;
	private var input:Scene3DInput;
	private var world:CollisionWorld3D = new CollisionWorld3D();
	private var colliders:Array<BoxCollider3D> = [];
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
	private var mask:Int = 3;
	private var elapsed:Float = 0;
	private var keys:Map<Int,Bool> = [];
	private var inputStage:Stage;
	private var lastAction:String = "资源加载中……";
	private var updates:Int = 0;
	override public function onStageInit():Void {
		super.onStageInit(); updateEnabled = true; sceneBackground.data = 0x172033; sceneBackground.alpha = 1;
		label("基础碰撞与角色控制 · 箱体 / 胶囊 / 连续扫掠",24,18,25,0xffffff);
		action("复位",24,65,function() { reset(new Vector3D(-5,0,0)); });
		action("直线撞墙",170,65,function() { scenario(new Vector3D(-4,0,0),new Vector3D(4,0,0)); });
		action("斜向滑动",360,65,function() { scenario(new Vector3D(-4,0,-1),new Vector3D(4,0,6)); });
		action("高处落地",550,65,function() { reset(new Vector3D(-5,7,2)); lastAction = "从世界 Y=7 落下，检查 grounded 与垂直速度"; });
		action("单次扫掠 20 米",760,65,highSpeed);
		action("初始重叠",24,105,function() { reset(new Vector3D(0,0,0)); lastAction = "传送进入墙内，下一次更新应推出或明确报告 stuck"; });
		action("封闭墙角",210,105,function() { scenario(new Vector3D(-4,0,-1),new Vector3D(3,0,-7)); });
		maskLabel = action("碰撞层：1 + 2",400,105,function() { mask = mask == 3 ? 1 : 3; if (controller != null) controller.collisionMask = mask; maskLabel.data = mask == 3 ? "碰撞层：1 + 2" : "碰撞层：仅 1"; });
		action("穿越蓝色层 2",650,105,function() { scenario(new Vector3D(-3,0,8),new Vector3D(-3,0,3)); });
		action("起跳",900,105,function() { if (controller != null) controller.jump(6); });
		view = new Scene3D(1072,490); view.x = 24; view.y = 150; view.backgroundColor = 0x26384c; view.backgroundAlpha = 1;
		view.ambientIntensity = 0.4; view.profilingEnabled = true; addChild(view);
		var camera = new Camera3D(); view.root.addChild(camera); view.camera = camera;
		var light = new DirectionalLight3D(0xffffff,0.8); light.direction = new Vector3D(-1,-2,-1); light.shadowEnabled = true; view.root.addChild(light); view.light = light;
		cameraControl = new OrbitCameraController3D(camera,new Vector3D(0,1,0)); cameraControl.yaw = 20; cameraControl.pitch = 48; cameraControl.distance = 24; cameraControl.minPitch = 10; cameraControl.maxDistance = 45; cameraControl.snap();
		input = new Scene3DInput(view,cameraControl); input.addEventListener(Scene3DInputEvent.SELECT,onSelect);
		box("地面",24,1,24,0,-0.5,0,0x637c89);
		box("中央墙",0.2,3,8,0,1.5,0,0xc87a69);
		box("墙角横墙",8,3,0.2,-4,1.5,-4,0xb47767);
		box("高速薄墙",0.05,3,6,6,1.5,0,0xe5c16b);
		box("蓝色层 2",5,2,0.25,-3,1,5,0x5a9cdb,2);
		box("低顶板",3,0.3,2.5,-5,2.7,7,0xa19acc);
		marker = visual(0.4,0.025,0.4,0xffda61); marker.visible = false;
		status = label("通过 Assets 加载带贴图角色……",24,656,15,0xd7e3fc);
		detail = label("",24,688,14,0xa9bad6);
		label("WASD／方向键：世界 X/Z 移动；空格：起跳；轻点地面：移动目标；左键拖动与滚轮：镜头。",24,720,14,0xa9bad6);
		label("红墙／黄薄墙为层 1，蓝墙为层 2；胶囊为竖直世界形状，不含台阶、坡面导航或动态刚体。",24,751,14,0xa9bad6);
		inputStage = stage; inputStage.addEventListener(Event.DEACTIVATE,onDeactivate);
		inputStage.addEventListener(KeyboardEvent.KEY_DOWN,onKeyDown); inputStage.addEventListener(KeyboardEvent.KEY_UP,onKeyUp);
		view.addEventListener(KeyboardEvent.KEY_DOWN,onKeyDown); view.addEventListener(KeyboardEvent.KEY_UP,onKeyUp); stage.focus = view;
		view.addEventListener(Event.FOCUS_OUT,onDeactivate);
		#if hxmaker_collision_checks
		CollisionChecks.run();
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
		request.loadModel("assets/robot.glb");
		request.onError(error -> { request.stop(); request.clean(); if (!isDisposed) { status.data = "加载失败："+error.error+"；可点击底部重新进入"; trace(status.data); } });
		request.onComplete(_ -> {
			if (isDisposed) { request.clean(); return; }
			try {
				var source = request.getModel("robot"); if (source == null || !source.texturesReady) throw "GLB 或贴图未准备好";
				model = source.createInstance(-1,{lightingEnabled:true}); model.setScale(0.6,0.6,0.6); view.root.addChild(model);
				for (mesh in model.meshes) mesh.castShadow = true; model.animation.play("Idle");
				controller = new CharacterController3D(world,model,0.35,1.9); controller.collisionMask = mask; reset(new Vector3D(-5,0,0));
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
	private function highSpeed():Void {
		if (controller == null) return; reset(new Vector3D(4,0,0));
		var result = controller.move(new Vector3D(20,0,0));
		lastAction = "单次请求 +X 20 米，实际 X="+round(controller.position.x)+"，应停在黄色薄墙前；接触数="+result.contacts.length;
		trace("HXMAKER_COLLISION_SWEEP "+haxe.Json.stringify({x:controller.position.x,blocked:result.blocked,stuck:result.stuck}));
	}
	private function onSelect(event:Scene3DInputEvent):Void {
		if (controller == null) return;
		var hit = world.raycast(event.ray,100,1);
		if (hit == null || hit.normal.y < 0.7) { lastAction = "请轻点可见地面；墙面拾取不会穿透到后方地面"; return; }
		goal = hit.point.clone(); lastAction = "目标 X/Z："+round(goal.x)+" / "+round(goal.z);
	}
	private function onKeyDown(event:KeyboardEvent):Void {
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
					+"　接触="+result.contacts.length+"　stuck="+result.stuck+"　预算耗尽="+result.iterationLimited+"　DrawCall="+view.stats.drawCalls;
				detail.data = lastAction;
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
		trace("HXMAKER_COLLISION_RELEASE "+haxe.Json.stringify({worldDisposed:world.isDisposed,colliders:world.colliders.length,updates:updates,
			controllerDisposed:controller == null || controller.isDisposed,inputDisposed:input == null || input.isDisposed,
			geometryReferences:geometryReferences,materialReferences:materialReferences}));
		colliders = []; geometries = []; materials = []; keys = []; goal = null; inputStage = null;
	}
}
