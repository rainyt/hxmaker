package;

import hx.assets.Assets;
import hx.collision3d.BoxCollider3D;
import hx.collision3d.CollisionWorld3D;
import hx.controls3d.CharacterController3D;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.Model3D;
import hx.display3d.Node3D;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;
import hx.light.Environment3D;
import hx.light.SkyEnvironment3D;
import hx.light.ShadowQuality3D;
import hx.render3d.SkyboxTexture3D;
import hx.utils.StorageTools;

/** 探索业务：加载 Blender 世界、角色碰撞、任务与版本化存档。 */
class ExplorerWorld {
	public var view(default,null):Scene3D;
	public var controller(default,null):CharacterController3D;
	public var collision(default,null):CollisionWorld3D;
	public var ready(default,null):Bool=false;
	public var failure(default,null):String="";
	public var yaw:Float=0;
	public var pitch:Float=-0.02;
	public var collected(default,null):Array<String>=[];
	public var gateOpen(default,null):Bool=false;
	public var complete(default,null):Bool=false;
	public var message:String="欢迎来到雪岭观测站。先与前方巡检机器人交谈。";
	public var onReady:Void->Void;
	public var onMessage:String->Void;
	public var interactions(default,null):Array<Dynamic>=[];
	public var isDisposed(default,null):Bool=false;
	private var assets:Assets;
	private var model:Model3D;
	private var player:Node3D;
	private var boxes:Array<BoxCollider3D>=[];
	private var gateBox:BoxCollider3D;
	private var gateNode:Node3D;
	private var settings:SkyEnvironment3D;
	private var environment:Environment3D;
	private var sky:SkyboxTexture3D;
	private var spawn:Vector3D;
	private var storage:StorageTools;
	private var autoSave:Float=0;
	private var initialFog:Dynamic;
	private var cameraPosition:Vector3D;
	private var cameraYaw:Float;
	private var cameraPitch:Float;

	public function new() {
		view=new Scene3D(1120,640);view.y=70;view.backgroundColor=0x9eacba;view.backgroundAlpha=1;view.autoRender=false;
		view.renderScale=0.8;view.ambientIntensity=0.38;view.bloom.enabled=true;view.bloom.threshold=0.85;view.bloom.intensity=0.25;
		var camera=new Camera3D();camera.near=0.08;camera.far=240;camera.fieldOfView=68;view.root.addChild(camera);view.camera=camera;
		var light=new DirectionalLight3D(0xffe7ca,2.2);light.direction=new Vector3D(-0.5,-1,-0.4);
		light.shadowEnabled=true;light.shadowQuality=ShadowQuality3D.BALANCED;light.shadowDistance=70;
		// 大片平面与远景使用较保守偏差，避免低分辨率阴影产生自遮挡条纹。
		light.shadowBias=0.0005;light.shadowSlopeBias=0.003;light.shadowNormalBias=1;
		view.root.addChild(light);view.light=light;
		collision=new CollisionWorld3D();player=new Node3D();view.root.addChild(player);
		storage=new StorageTools();storage.setSaveId("hxmaker-away-explorer-v1");
		assets=new Assets();assets.tryLoadTimes=0;
		assets.loadModel("assets/world/world.glb");assets.loadJson("assets/world/scene.json");assets.loadJson("assets/world/fog.json");
		assets.loadBitmapData("assets/world/sky.png");assets.loadJson("assets/world/sky.json");
		assets.loadBitmapData("assets/world/environment.png");assets.loadJson("assets/world/environment.json");
		assets.onComplete(_->{
			if(isDisposed){assets.clean();return;}
			try{build();ready=true;if(onReady!=null)onReady();}
			catch(error:Dynamic){failure="场景创建失败："+Std.string(error);trace(failure);}
		});
		assets.onError(error->{if(!isDisposed){failure="资源加载失败："+error.error;trace(failure);}});
		assets.start();
	}
	private function build():Void {
		var data:Dynamic=assets.getObject("scene");if(data.format!="hxmaker-explorer-world-1")throw "世界清单版本不支持";
		spawn=vector(data.spawn);interactions=cast data.interactions;
		model=assets.getModel("world").createInstance(-1,{pbrEnabled:true});view.root.addChild(model);
		for(mesh in model.meshes){mesh.castShadow=mesh.name.indexOf("terrain")<0&&mesh.name.indexOf("courtyard")<0;mesh.receiveShadow=mesh.name.indexOf("pine")<0&&mesh.name.indexOf("terrain")<0;}
		var definitions:Array<Dynamic>=cast data.colliders;
		for(definition in definitions){
			var size=vector(definition.size),box=new BoxCollider3D(size.x,size.y,size.z);box.offset=vector(definition.position);
			collision.add(box);boxes.push(box);if(definition.id=="gate")gateBox=box;
		}
		gateNode=findNode("gate");if(gateNode==null||gateBox==null)throw "世界缺少闸门节点或碰撞代理";
		controller=new CharacterController3D(collision,player,0.32,1.75);controller.stepOffset=0.3;
		sky=SkyboxTexture3D.fromData(assets.getBitmapData("sky"),assets.getObject("sky"));
		environment=Environment3D.fromData(assets.getBitmapData("environment"),assets.getObject("environment"));
		settings=new SkyEnvironment3D(sky,environment);settings.skybox.toneMapping=true;settings.environment.intensity=0.65;settings.applyTo(view);
		initialFog=assets.getObject("fog");view.fog.setData(initialFog);
		controller.teleport(spawn);load();syncProgress();updateCamera();
	}
	private static function vector(value:Dynamic):Vector3D {
		var items:Array<Dynamic>=cast value;
		if(items==null||items.length!=3)throw "世界向量无效";
		for(item in items)if((!Std.isOfType(item,Int)&&!Std.isOfType(item,Float))||!Math.isFinite(item))throw "世界坐标必须有限";
		return new Vector3D(items[0],items[1],items[2]);
	}
	private function findNode(name:String):Node3D {var nodes=model.findNodes(name);return nodes.length==0?null:nodes[0];}
	public function update(dt:Float,forward:Float,strafe:Float,running:Bool):Void {
		if(!ready||isDisposed)return;
		dt=Math.max(0,Math.min(0.1,dt));
		var velocity=new Vector3D(Math.sin(yaw)*forward+Math.cos(yaw)*strafe,0,-Math.cos(yaw)*forward+Math.sin(yaw)*strafe);
		if(velocity.length>1)velocity.normalize();velocity.scaleBy(running?7.5:4.5);
		var remaining=dt;while(remaining>0){var step=Math.min(1/60,remaining);controller.update(step,velocity);remaining-=step;}
		if(controller.position.y < -5)controller.teleport(spawn);
		updateCamera();autoSave+=dt;if(autoSave>=8){autoSave=0;save(false);}
	}
	public function look(dx:Float,dy:Float):Void {yaw=(yaw+dx)%(Math.PI*2);pitch=Math.max(-1.3,Math.min(1.3,pitch+dy));updateCamera();}
	private function updateCamera():Void {
		if(controller==null)return;
		var position=controller.position;position.y+=1.58;
		// 相机姿态未变时保留场景缓存，静止期间只合成已有的三维画面。
		if(cameraPosition!=null&&position.x==cameraPosition.x&&position.y==cameraPosition.y&&position.z==cameraPosition.z&&yaw==cameraYaw&&pitch==cameraPitch)return;
		view.camera.lookFrom(position,position.add(new Vector3D(Math.sin(yaw)*Math.cos(pitch),Math.sin(pitch),-Math.cos(yaw)*Math.cos(pitch))));
		cameraPosition=position;cameraYaw=yaw;cameraPitch=pitch;
	}
	public function jump():Void {if(ready)controller.jump(6);}
	public function nearest():Dynamic {
		if(!ready)return null;
		var best:Dynamic=null,bestDistance=1e10,position=controller.position;
		for(item in interactions){var point=vector(item.position),dx=point.x-position.x,dz=point.z-position.z,distance=Math.sqrt(dx*dx+dz*dz);
			if(distance<=item.radius&&distance<bestDistance){best=item;bestDistance=distance;}}
		return best;
	}
	public function hint():String {
		var item=nearest();if(item==null)return "WASD 移动 · 拖动环顾 · Shift 奔跑 · 空格跳跃";
		return "[E / 交互] "+item.label+(item.kind=="beacon"&&collected.indexOf(item.id)>=0?"（已激活）":"");
	}
	public function interact():Void {
		var item=nearest();if(item==null){say("靠近信标、机器人或终端后再交互。");return;}
		switch(item.kind){
			case "robot":say("巡检协议：激活西侧气象、东侧地质和南侧通讯三个信标，再到北侧档案馆开启闸门。右上角地图会标出目标。");
			case "lore":say("纪念像铭文：此站记录着山脉的变化。模型来自旧 Away3D 示例，如今通过 Blender 与 GLB 再次进入世界。");
			case "beacon":
				if(collected.indexOf(item.id)<0){collected.push(item.id);syncProgress();save(false);say(item.label+"已激活。观测网络 "+collected.length+" / 3。"+(collected.length==3?"请前往北侧档案馆。":""));}
				else say("这个信标已经完成校准。");
			case "gate":
				if(collected.length<3)say("闸门需要三个观测信标，目前还差 "+(3-collected.length)+" 个。");
				else{gateOpen=!gateOpen;syncProgress();save(false);say(gateOpen?"闸门已开启，进入档案馆读取核心档案。":"闸门已关闭。");}
			case "archive":
				if(!gateOpen||collected.length<3)say("请先恢复观测网络并打开档案馆闸门。");
				else{complete=true;save(false);say("调查完成！核心档案已恢复。你可以继续探索、保存位置，或点击新旅程重新开始。");}
		}
	}
	private function syncProgress():Void {
		if(gateNode!=null)gateNode.visible=!gateOpen;if(gateBox!=null)gateBox.enabled=!gateOpen;
		for(item in interactions)if(item.kind=="beacon"){var node=findNode(item.node);if(node!=null)node.visible=collected.indexOf(item.id)<0;}
	}
	private function say(value:String):Void {message=value;if(onMessage!=null)onMessage(value);trace("HXMAKER_EXPLORER "+value);}
	public function save(notify:Bool=true):Void {
		if(controller==null)return;
		var p=controller.position;
		try{storage.setKeyValue("progress",{version:1,collected:collected.copy(),gateOpen:gateOpen,complete:complete,position:[p.x,p.y,p.z],yaw:yaw,pitch:pitch});if(notify)say("进度和当前位置已保存。");}
		catch(error:Dynamic){if(notify)say("存档失败："+Std.string(error));}
	}
	private function load():Void {
		try{
			var data:Dynamic=storage.getKeyValue("progress",null);if(data==null||data.version!=1)return;
			var ids:Array<Dynamic>=cast data.collected;if(ids==null)return;
			collected=[];for(id in ["west","east","south"])if(ids.indexOf(id)>=0)collected.push(id);
			gateOpen=data.gateOpen==true&&collected.length==3;complete=data.complete==true&&gateOpen;
			var p=vector(data.position);
			if(Math.abs(p.x)<29&&p.z> -33&&p.z<33&&p.y>= -0.1&&p.y<5&&!(p.z< -8&&Math.abs(p.x)<10&&!gateOpen))controller.teleport(p);
			var angle:Dynamic=data.yaw,tilt:Dynamic=data.pitch;
			if((Std.isOfType(angle,Int)||Std.isOfType(angle,Float))&&Math.isFinite(angle))yaw=angle%(Math.PI*2);
			if((Std.isOfType(tilt,Int)||Std.isOfType(tilt,Float))&&Math.isFinite(tilt))pitch=Math.max(-1.3,Math.min(1.3,tilt));
			message="已恢复上次进度。观测网络 "+collected.length+" / 3。";
		}catch(_:Dynamic){message="旧存档无效，已回到观测站入口。";}
	}
	public function newJourney():Void {
		if(!ready)return;storage.removeKeyValue("progress");collected=[];gateOpen=false;complete=false;yaw=0;pitch=-0.02;
		controller.teleport(spawn);view.fog.setData(initialFog);syncProgress();updateCamera();save(false);say("新旅程开始。先找到巡检机器人，或按地图探索三个信标。");
	}
	public function dispose():Void {
		if(isDisposed)return;save(false);isDisposed=true;ready=false;
		if(settings!=null)settings.dispose();if(controller!=null)controller.dispose();
		for(box in boxes)box.dispose();collision.dispose();view.dispose();
		if(sky!=null)sky.dispose();if(environment!=null)environment.dispose();assets.clean();
	}
}
