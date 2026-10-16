package;

import hx.core.Engine;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.Scene3D;
import hx.display.Camera3D;
import hx.display.MeshObject;
import hx.display.Node3D;
import hx.display.Label;
import hx.display.Quad;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.material.AlphaMode3D;
import hx.material.UnlitTextureMaterial;

/** 无外部资源的基础三维示例：多纹理、父子变换、透明、UI 与拾取。 */
class Main extends openfl.display.Sprite {
	private var scene:Scene3D;
	private var camera:Camera3D;
	private var models:Node3D;
	private var status:Label;
	private var time:Float = 0;
	private var sources:Array<openfl.display.BitmapData> = [];
	public function new() {
		super();
		var engine = Hxmaker.init(Engine, 960, 640);
		engine.initOpenFLRoot(this);
		var stage = Hxmaker.topView;
		stage.addChild(new Quad(960, 640, 0x172033));
		scene = new Scene3D(912, 500); scene.x = 24; scene.y = 80;
		scene.backgroundColor = 0x24334d; scene.backgroundAlpha = 1;
		stage.addChild(scene);
		camera = new Camera3D(); camera.setPosition(0, 4, 9); scene.root.addChild(camera); scene.camera = camera;
		camera.lookAt(new Vector3D(0, 0, 0));
		models = new Node3D(); scene.root.addChild(models);
		var box = BoxGeometry.create();
		var colors = [0xe76f51, 0xf4a261, 0xe9c46a, 0x2a9d8f, 0x3a86ff, 0x8338ec];
		for (i in 0...12) {
			var source = checker(colors[i % colors.length]); sources.push(source);
			var material = new UnlitTextureMaterial(OpenFlBitmapData.fromBitmapData(source));
			var mesh = new MeshObject(box, material); mesh.name = "模型 " + (i + 1);
			mesh.setPosition((i % 4 - 1.5) * 1.7, 0, (Std.int(i / 4) - 1) * 1.7);
			models.addChild(mesh);
		}
		var floor = new MeshObject(PlaneGeometry.create(12, 10), new UnlitTextureMaterial(null, 0x53657d));
		floor.y = -0.8; floor.name = "地面"; scene.root.addChild(floor);
		var glassMaterial = new UnlitTextureMaterial(null, 0x7bdff2);
		glassMaterial.alphaMode = AlphaMode3D.BLEND; glassMaterial.opacity = 0.35;
		var glass = new MeshObject(BoxGeometry.create(1.4, 1.4, 1.4), glassMaterial);
		glass.setPosition(0, 1.4, 0); glass.name = "透明模型"; scene.root.addChild(glass);
		var title = new Label("基础 3D：点击模型拾取，点击此处切换多纹理");
		title.fontSize = 22; title.color = 0xffffff; title.x = 24; title.y = 22;
		stage.addChild(title);
		status = new Label("等待首帧绘制"); status.fontSize = 16; status.color = 0xd7e3fc; status.x = 24; status.y = 594;
		stage.addChild(status);
		title.addEventListener(MouseEvent.CLICK, function(_) { scene.multiTextureEnabled = !scene.multiTextureEnabled; scene.requestRender(); });
		scene.addEventListener(MouseEvent.CLICK, function(event:MouseEvent) {
			var hit = scene.pick(event.stageX, event.stageY);
			if (hit != null) title.data = "已选中：" + hit.object.name + "；点击此处切换多纹理";
		});
		scene.addEventListener(Event.UPDATE, function(_) {
			var dt = Hxmaker.engine.dt; time += dt; models.rotationY += dt * 10; glass.rotationY -= dt * 25;
			camera.setPosition(Math.sin(time * 0.12) * 2, 4, 9); camera.lookAt(new Vector3D(0, 0, 0));
			status.data = "多纹理：" + (scene.multiTextureEnabled ? "开启" : "关闭") + "　3D 批次：" + scene.stats.drawCalls
				+ "　纹理槽位：" + scene.stats.textureSlots + "　三角形：" + scene.stats.triangles;
		});
		#if hxmaker_3d_regression
		new Regression3D(sources[0]);
		#if hxmaker_3d_regression_2d_only
		scene.visible = false;
		#end
		#end
	}
	private function checker(color:Int):openfl.display.BitmapData {
		var bitmap = new openfl.display.BitmapData(64, 64, true, 0xff000000 | color);
		for (y in 0...4) for (x in 0...4) if ((x + y) % 2 == 0)
			bitmap.fillRect(new openfl.geom.Rectangle(x * 16, y * 16, 16, 16), 0xff000000 | ((color >> 1) & 0x7f7f7f));
		return bitmap;
	}
}
