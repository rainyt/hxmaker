package;

import hx.assets.Assets;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Label;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.material.Material3D;
import hx.material.LambertTextureMaterial;
import hx.material.PbrMaterial3D;
import hx.render3d.FogMode3D;
import hx.render3d.Skybox3D;
import hx.render3d.SkyboxTexture3D;

/** 距离雾示例；业务参数独立于模型资源及 Blender 导出来源。 */
class GameStage extends hx.display.Stage {
	private var scene:Scene3D;
	private var input:Scene3DInput;
	private var orbit:OrbitCameraController3D;
	private var geometry:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var assets:Assets;
	private var sky:SkyboxTexture3D;
	private var status:Label;
	#if hxmaker_fog_checks
	private var checks:FogChecks;
	#end
	override public function onStageInit():Void {
		super.onStageInit();
		scene = new Scene3D(912, 440); scene.x = 24; scene.y = 130; scene.autoRender = false;
		scene.backgroundColor = 0x809eb8; scene.backgroundAlpha = 1;
		var camera = new Camera3D(); camera.lookFrom(new Vector3D(12, 9, 15), new Vector3D(0, 0, -22));
		scene.root.addChild(camera); scene.camera = camera; addChild(scene);
		orbit = new OrbitCameraController3D(camera, new Vector3D(0, 0, -22)); input = new Scene3DInput(scene, orbit);
		scene.fog.enabled = true; scene.fog.start = 12; scene.fog.end = 65; scene.fog.color = 0x809eb8;
		scene.ambientIntensity = 0.8;
		var box = BoxGeometry.create(3, 5, 3); geometry.push(box);
		for (row in 0...8) for (column in 0...2) {
			var material:Material3D = column == 0 ? new LambertTextureMaterial(null, 0xd78a48) : new PbrMaterial3D(null, 0x4b91b5, 0.1, 0.65);
			materials.push(material); var mesh = new MeshObject(box, material);
			mesh.setPosition(column == 0 ? -6 : 6, 2.5, -row * 9); scene.root.addChild(mesh);
		}
		var floor = PlaneGeometry.create(35, 100); geometry.push(floor);
		var floorMaterial = new LambertTextureMaterial(null, 0x6e7667); materials.push(floorMaterial);
		var mesh = new MeshObject(floor, floorMaterial); mesh.z = -30; scene.root.addChild(mesh);
		label("距离雾：拖动旋转，滚轮缩放；远处物体逐渐融入雾色",24,18,21);
		action("雾开关",24,()->scene.fog.enabled=!scene.fog.enabled);
		action("线性",170,()->scene.fog.mode=FogMode3D.LINEAR);
		action("指数",290,()->scene.fog.mode=FogMode3D.EXP);
		action("平方指数",410,()->scene.fog.mode=FogMode3D.EXP2);
		action("天空受雾",590,()->scene.fog.affectSkybox=!scene.fog.affectSkybox);
		action("Bloom",790,()->scene.bloom.enabled=!scene.bloom.enabled);
		status = label("",24,590,15);
		addEventListener(Event.UPDATE, _->{ orbit.update(hx.core.Hxmaker.engine.dt);
			status.data="模式："+scene.fog.mode+"　雾："+scene.stats.fogStatus+"　模型批次："+scene.stats.drawCalls+"　重绘："+scene.stats.redrawId;
		});
		assets = new Assets(); assets.loadBitmapData("assets/sky/sky.png"); assets.loadJson("assets/sky/sky.json");
		assets.onComplete(_->{
			if(isDisposed){assets.clean();return;}
			sky = SkyboxTexture3D.fromData(assets.getBitmapData("sky"), assets.getObject("sky"));
			scene.skybox = new Skybox3D(sky); scene.skybox.toneMapping = true;
			#if hxmaker_fog_checks
			checks = new FogChecks(this, sky);
			#end
		});
		assets.onError(error->trace("距离雾示例资源加载失败："+error.error)); assets.start();
	}
	private function label(text:String,x:Float,y:Float,size:Int):Label {var value=new Label(text);value.x=x;value.y=y;value.fontSize=size;value.color=0xe0ecff;addChild(value);return value;}
	private function action(text:String,x:Float,callback:Void->Void):Void {var value=label(text,x,80,18);value.mouseEnabled=true;value.addEventListener(MouseEvent.CLICK,_->callback());}
	override public function dispose():Void {
		if(isDisposed)return;
		#if hxmaker_fog_checks
		if(checks!=null)checks.dispose();
		#end
		input.dispose();orbit.dispose();
		var config=scene.skybox;super.dispose();if(config!=null)config.dispose();if(sky!=null)sky.dispose();assets.clean();
		for(value in geometry)value.dispose();for(value in materials)value.dispose();
	}
}
