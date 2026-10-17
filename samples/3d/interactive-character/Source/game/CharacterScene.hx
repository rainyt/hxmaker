package game;

import app.GameContext;
import hx.assets.ModelAsset;
import hx.controls3d.FollowCameraController3D;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display3d.Camera3D;
import hx.display.Label;
import hx.display3d.MeshObject;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.display.Sprite;
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
import hx.render3d.Math3D;
import ui.SampleScene;

/** 完整业务场景；step 仅由 PlayProcedure 调用，显示树更新只维护显示与视口设置。 */
class CharacterScene extends SampleScene {
	public var elapsed(default, null):Float = 0;
	public var hasRendered(get, never):Bool;
	private var context:GameContext;
	private var source:ModelAsset;
	private var view:Scene3D;
	private var actors:Array<CharacterActor> = [];
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var orbit:OrbitCameraController3D;
	private var follow:FollowCameraController3D;
	private var input:Scene3DInput;
	private var selected:Int = 0;
	private var followMode:Bool = true;
	private var paused:Bool = false;
	private var autoMove:Bool = false;
	private var hand:String = "R";
	private var attachmentVisible:Bool = true;
	private var speed:Float = 1;
	private var waypoint:Int = 0;
	private var marker:MeshObject;
	private var goalMarker:MeshObject;
	private var status:Label;
	private var detail:Label;
	private var statusTime:Float = 0;
	private var lastRenderId:Int = -1;
	private var uiClicks:Int = 0;
	private var lastAction:String = "左键点击选择／移动，左键拖动转镜头，滚轮缩放。";
	private var buttons:Array<{label:Label,caption:Void->String}> = [];
	private function get_hasRendered():Bool { return view != null && view.stats.renderId > 0; }
	public function new(context:GameContext, source:ModelAsset) {
		super(); this.context = context; this.source = source; context.audit.worldsCreated++; context.audit.log("创建角色场景");
	}
	override public function onStageInit():Void {
		super.onStageInit();
		label("完整角色场景 · 流程 / 资源 / 动画 / 相机 / 交互",24,18,25,0xffffff);
		button(0,() -> "下一个角色",function() { selectActor((selected+1)%actors.length); });
		button(1,() -> "相机："+(followMode ? "跟随" : "环绕"),switchCamera);
		button(2,() -> "自动移动："+(autoMove ? "开" : "关"),function() { autoMove = !autoMove; if (!autoMove) actors[selected].stop(); });
		button(3,() -> "角色："+(paused ? "暂停" : "运行"),function() { paused = !paused; });
		button(4,() -> "重新取景",resetCamera);
		button(5,() -> "多纹理："+(view.multiTextureEnabled ? "开" : "关"),function() { view.multiTextureEnabled = !view.multiTextureEnabled; });
		button(6,() -> "阴影："+(view.light.shadowEnabled ? "开" : "关"),function() { view.light.shadowEnabled = !view.light.shadowEnabled; });
		button(7,() -> "挂点："+(hand == "R" ? "右手" : "左手"),function() { hand = hand == "R" ? "L" : "R"; for (actor in actors) actor.setHand(hand); });
		button(8,() -> "道具："+(attachmentVisible ? "显示" : "隐藏"),function() { attachmentVisible = !attachmentVisible; for (actor in actors) actor.setAttachmentVisible(attachmentVisible); });
		button(9,() -> "速度："+speed+" 倍",function() { speed = speed == 1 ? 2 : speed == 2 ? 0.5 : 1; });
		view = new Scene3D(1072,520); view.x = 24; view.y = 146; view.backgroundColor = 0x24334d; view.backgroundAlpha = 1; view.ambientIntensity = 0.35; view.profilingEnabled = true; addChild(view);
		var camera = new Camera3D(); view.root.addChild(camera); view.camera = camera;
		var light = new DirectionalLight3D(0xffffff,0.85); light.direction = new Vector3D(-1,-2,-1); light.shadowEnabled = true; view.root.addChild(light); view.light = light;
		var floorGeometry = PlaneGeometry.create(24,24), floorMaterial = ownMaterial(new LambertTextureMaterial(null,0x667d93)); floorMaterial.cullMode = CullMode3D.NONE;
		geometries.push(floorGeometry); var floor = new MeshObject(floorGeometry,floorMaterial); floor.y = -0.025; floor.pickable = false; view.root.addChild(floor);
		marker = ownBox(1.2,0.025,0.95,0xffda61); marker.y = 0.01;
		goalMarker = ownBox(0.4,0.03,0.4,0xff7868); goalMarker.y = 0.02; goalMarker.visible = false;
		var propGeometry = BoxGeometry.create(0.18,0.9,0.18); geometries.push(propGeometry);
		var propMaterial = ownMaterial(new LambertTextureMaterial(source.getTexture(2))); propMaterial.cullMode = CullMode3D.NONE; propMaterial.colorMultiplyLinear = true;
		for (i in 0...context.config.characterCount) {
			var actor = new CharacterActor(source,propGeometry,propMaterial,context.config.fadeSeconds,i); actors.push(actor); view.root.addChild(actor.model);
			actor.model.x = (i-(context.config.characterCount-1)/2)*2.2;
		}
		if (actors.length == 0) throw "角色数量必须大于零";
		selected = Std.int(actors.length/2);
		orbit = new OrbitCameraController3D(camera,new Vector3D(0,1.5,0)); orbit.minPitch = 5; orbit.maxDistance = 40;
		follow = new FollowCameraController3D(camera,actors[selected].model); follow.minPitch = 5; follow.maxDistance = 40;
		input = new Scene3DInput(view,follow); input.maxDistance = 150; input.addEventListener(Scene3DInputEvent.SELECT,onSelect);
		buildOverlay(); status = label("准备进入场景……",24,682,15); detail = label(lastAction,24,710,14,0xa9bad6);
		resetCamera(); updateButtons(); source = null;
	}
	private function button(index:Int,caption:Void->String,callback:Void->Void):Void {
		var value = action("",24+(index%5)*216,64+Std.int(index/5)*36,function() { callback(); updateButtons(); }); value.fontSize = 16;
		buttons.push({label:value,caption:caption});
	}
	private function updateButtons():Void { for (button in buttons) button.label.data = button.caption(); }
	private function ownMaterial(value:Material3D):Material3D { materials.push(value); return value; }
	private function ownBox(width:Float,height:Float,depth:Float,color:Int):MeshObject {
		var geometry = BoxGeometry.create(width,height,depth); geometries.push(geometry);
		var material = ownMaterial(new LambertTextureMaterial(null,color)); material.cullMode = CullMode3D.NONE;
		var mesh = new MeshObject(geometry,material); mesh.pickable = false; view.root.addChild(mesh); return mesh;
	}
	private function buildOverlay():Void {
		var box = new Sprite(); box.x = 48; box.y = 170; box.mouseChildren = false; box.addChild(new Quad(272,38,0x354c71));
		var text = new Label("场景 UI：点击不会穿透到地面"); text.x = 9; text.y = 8; text.fontSize = 15; text.color = 0xffffff; box.addChild(text); addChild(box);
		for (type in [MouseEvent.MOUSE_DOWN,MouseEvent.MOUSE_MOVE,MouseEvent.MOUSE_UP]) box.addEventListener(type,function(event:MouseEvent) { event.preventDefault(); });
		box.addEventListener(MouseEvent.CLICK,function(event:MouseEvent) { uiClicks++; event.preventDefault(); });
	}
	private function selectActor(index:Int):Void { selected = index; follow.targetNode = actors[selected].model; lastAction = "已选择角色 "+(selected+1); }
	private function onSelect(event:Scene3DInputEvent):Void {
		if (event.hit != null && event.hit.model != null) {
			for (i in 0...actors.length) if (actors[i].model == event.hit.model) { selectActor(i); lastAction += " / "+event.hit.object.name; return; }
			return;
		}
		var distance = event.ray.intersectPlane(new Vector3D(0,1,0),0,150); if (distance == null) return;
		var point = event.ray.at(distance);
		if (Math.abs(point.x) > 10 || Math.abs(point.z) > 10) { lastAction = "目标超出地面范围"; return; }
		autoMove = false; actors[selected].moveTo(point.x,point.z); lastAction = "角色 "+(selected+1)+" 移动到 ("+Math.round(point.x*10)/10+", "+Math.round(point.z*10)/10+")"; updateButtons();
	}
	private function switchCamera():Void {
		input.cancel("cameraChanged"); followMode = !followMode;
		if (followMode) { follow.syncFromCamera(); input.controller = follow; } else { orbit.syncFromCamera(); input.controller = orbit; }
	}
	private function resetCamera():Void {
		if (orbit == null) return;
		orbit.target.setTo(0,1.5,0); orbit.yaw = 12; orbit.pitch = 25; orbit.distance = Math.max(10,actors.length*1.6);
		follow.yaw = 12; follow.pitch = 22; follow.distance = 10;
		if (followMode) follow.snap(); else orbit.snap();
	}
	public function step(dt:Float):Void {
		if (isDisposed) return;
		if (!Math3D.finite(dt) || dt < 0) throw "角色场景时间步长无效";
		elapsed += dt; context.audit.simulationUpdates++; recordRender();
		if (autoMove && !paused && actors[selected].goal == null) {
			var points = [new Vector3D(-4,0,-3),new Vector3D(4,0,-3),new Vector3D(4,0,3),new Vector3D(-4,0,3)], point = points[waypoint++%4];
			actors[selected].moveTo(point.x,point.z);
		}
		for (actor in actors) if (actor.step(dt,context.config.movementSpeed*speed,speed,paused)) context.audit.animationUpdates++;
		var actor = actors[selected]; marker.x = actor.model.x; marker.z = actor.model.z; goalMarker.visible = actor.goal != null;
		if (actor.goal != null) { goalMarker.x = actor.goal.x; goalMarker.z = actor.goal.z; }
		if (followMode) follow.update(dt); else orbit.update(dt);
		statusTime += dt;
		if (statusTime >= 0.2) {
			statusTime = 0;
			status.data = "角色："+actors.length+"　选中："+(selected+1)+"　动作："+actor.model.animation.currentName+"　主批次："+view.stats.drawCalls
				+"　槽位："+view.stats.textureSlots+"　渲染 CPU："+Math.round(view.stats.renderCpuMs*100)/100+"ms";
			detail.data = lastAction+"　UI 点击："+uiClicks+"　捕获："+input.capturing; updateButtons();
		}
	}
	private function recordRender():Void {
		var stats = view.stats;
		if (!stats.profileReady || stats.renderId == lastRenderId) return;
		lastRenderId = stats.renderId;
		context.audit.render(stats.renderCpuMs,{renderId:stats.renderId,drawCalls:stats.redrawThisFrame ? stats.drawCalls : 0,textureSlots:stats.textureSlots,
			uploadedBytes:stats.redrawThisFrame ? stats.uploadedBytes : 0,renderCpuMs:stats.renderCpuMs,shadowCpuMs:stats.shadowCpuMs,mainCpuMs:stats.mainCpuMs,
			stateCpuMs:stats.stateCpuMs,compositeCpuMs:stats.compositeCpuMs});
	}
	public function suspendInput():Void { if (input != null && !input.isDisposed) input.enabled = false; }
	override public function dispose():Void {
		if (isDisposed) return;
		var rendered = hasRendered;
		if (view != null) recordRender();
		if (input != null) input.dispose();
		for (actor in actors) actor.dispose();
		if (orbit != null) orbit.dispose(); if (follow != null) follow.dispose();
		super.dispose();
		var geometryReferences = 0, materialReferences = 0, modelsDisposed = true;
		for (actor in actors) if (!actor.model.isDisposed) modelsDisposed = false;
		for (geometry in geometries) geometryReferences += geometry.referenceCount;
		for (material in materials) materialReferences += material.referenceCount;
		var report = {modelsDisposed:modelsDisposed,inputDisposed:input == null || input.isDisposed,viewDisposed:view == null || view.isDisposed,
			controllersDisposed:(orbit == null || orbit.isDisposed) && (follow == null || follow.isDisposed),
			geometryReferences:geometryReferences,materialReferences:materialReferences,ownedResourcesDisposed:false,rendered:rendered};
		context.audit.release(report);
		for (geometry in geometries) geometry.dispose(); for (material in materials) material.dispose(); report.ownedResourcesDisposed = true;
		actors = []; geometries = []; materials = []; source = null;
		context.audit.worldsDisposed++; context.audit.log("角色场景已销毁，外部几何与材质引用归零");
	}
}
