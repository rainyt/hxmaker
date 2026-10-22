package;

import hx.assets.Assets;
import hx.assets.ModelAsset;
import hx.display3d.Camera3D;
import hx.display.DisplayObjectContainer;
import hx.display.Image;
import hx.display.Label;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.display.Scroll;
import hx.display.Sprite;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.Material3D;
import hx.material.LambertTextureMaterial;

/** 场景的创建、更新与销毁由固定配置驱动；不在性能样本中变更负载。 */
class AcceptanceWorld {
	public var layer(default,null):Sprite;
	public var scenes(default,null):Array<Scene3D> = [];
	public var models(default,null):Array<Model3D> = [];
	public var lastAnimationMs(default,null):Float = 0;
	public var configuration(default,null):CaseSpec;
	public var probe(default,null):SamplerProbe;
	private var assets:Assets;
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var boxes:Array<MeshObject> = [];
	private var previews:Array<Image> = [];
	private var frame:Int = 0;
	public function new(assets:Assets,spec:CaseSpec,diagnostic:Bool = false) {
		this.assets = assets; configuration = spec; layer = new Sprite();
		try {
			var source = assets.getModel(spec.dense ? "robot-dense" : "robot");
			var before = new Image(source.getTexture(0)); before.width = before.height = 64; before.y = 435;
			if (diagnostic) { probe = new SamplerProbe(source.getTexture(0)); layer.addChild(probe.prefix); }
			layer.addChild(before); previews.push(before);
			if (probe != null) layer.addChild(probe.before);
			var scene = createScene(900,420,spec); var host:DisplayObjectContainer = layer;
			if (spec.nestedMask) {
				var outer = clip(900,420), inner = clip(830,370); inner.x = 35; inner.y = 25;
				layer.addChild(outer); outer.addChild(inner); host = inner;
				scene.x = -35; scene.y = -25;
			}
			host.addChild(scene);
			if (spec.kind == "boxes") addBoxes(scene,spec.count);
			else if (spec.kind == "actors") addModels(scene,source,spec.count);
			if (spec.kind != "empty") addFloor(scene);
			if (spec.secondView) {
				var second = createScene(240,170,spec); second.x = 645; second.y = 15;
				addModels(second,source,2); addFloor(second); layer.addChild(second);
			}
			if (probe != null) layer.addChild(probe.after);
			var after = new Image(source.getTexture(0)); after.width = after.height = 64; after.x = 86; after.y = 435;
			layer.addChild(after); previews.push(after);
			if (probe != null) layer.addChild(probe.end);
			var overlay = new Quad(240,34,0xe39f37); overlay.x = 650; overlay.y = 370; layer.addChild(overlay);
			var note = new Label("二维覆盖层：文字与橙色条应完整"); note.fontSize = 13; note.color = 0x182333;
			note.x = 655; note.y = 377; layer.addChild(note);
			var legend = new Label("左图在 3D 之前绘制，右图在之后绘制；诊断时交替平滑设置。");
			legend.x = 165; legend.y = 448; legend.fontSize = 14; legend.color = 0xb9cce9; layer.addChild(legend);
		} catch (error:Dynamic) { dispose(); throw error; }
	}
	private function clip(width:Float,height:Float):Scroll {
		var scroll = new Scroll(false); scroll.width = width; scroll.height = height;
		scroll.scrollXEnable = false; scroll.scrollYEnable = false; return scroll;
	}
	private function createScene(width:Float,height:Float,spec:CaseSpec):Scene3D {
		var scene = new Scene3D(width,height); scenes.push(scene);
		scene.backgroundColor = 0x273a52; scene.backgroundAlpha = 1; scene.ambientIntensity = 0.32;
		scene.multiTextureEnabled = spec.multi; scene.renderScale = spec.renderScale;
		scene.autoRender = !spec.cached; scene.profilingEnabled = true;
		var camera = new Camera3D(); scene.root.addChild(camera); scene.camera = camera;
		var size = spec.kind == "boxes" ? Math.ceil(Math.sqrt(spec.count))*0.7 : Math.ceil(Math.sqrt(Math.max(1,spec.count)))*1.6;
		if (width < 300) size = 3.5;
		camera.near = 0.05; camera.far = 200;
		camera.setPosition(size*0.4,Math.max(4,size*0.9),Math.max(7,size*1.8)); camera.lookAt(new Vector3D(0,1,0));
		var light = new DirectionalLight3D(0xffffff,0.85); scene.root.addChild(light); scene.light = light;
		light.direction = new Vector3D(-1,-2,-1); light.shadowEnabled = spec.shadow; light.shadowMapSize = spec.shadowSize;
		return scene;
	}
	private function addModels(scene:Scene3D,source:ModelAsset,count:Int):Void {
		var columns = Std.int(Math.ceil(Math.sqrt(count))), rows = Std.int(Math.ceil(count/columns));
		for (i in 0...count) {
			var model = source.createInstance(-1,{lightingEnabled:true}); models.push(model); scene.root.addChild(model);
			model.setPosition((i%columns-(columns-1)/2)*2.2,0,(Std.int(i/columns)-(rows-1)/2)*2.6);
			model.animation.play("Walk",true); model.animation.seek(model.animation.duration*(i%10)/10);
			for (mesh in model.meshes) mesh.castShadow = configuration.shadow;
			if (!configuration.animated) model.animation.pause();
		}
	}
	private function addBoxes(scene:Scene3D,count:Int):Void {
		var geometry = BoxGeometry.create(0.85,0.85,0.85); geometries.push(geometry);
		var bank:Array<Material3D> = [];
		for (i in 0...20) {
			var material = new LambertTextureMaterial(assets.getBitmapData(tile(i))); material.cullMode = CullMode3D.NONE;
			material.colorMultiplyLinear = true; materials.push(material); bank.push(material);
		}
		var columns = Std.int(Math.ceil(Math.sqrt(count)));
		for (i in 0...count) {
			var mesh = new MeshObject(geometry,bank[i%20]); boxes.push(mesh); scene.root.addChild(mesh);
			mesh.setPosition((i%columns-(columns-1)/2)*1.1,0.45,(Std.int(i/columns)-(columns-1)/2)*1.1);
		}
	}
	private function addFloor(scene:Scene3D):Void {
		var geometry = PlaneGeometry.create(80,80); geometries.push(geometry);
		var material = new LambertTextureMaterial(null,0x71859a); material.cullMode = CullMode3D.NONE;
		material.colorMultiplyLinear = true; materials.push(material);
		var floor = new MeshObject(geometry,material); floor.y = -0.06; floor.pickable = false; scene.root.addChild(floor);
	}
	public static function tile(index:Int):String { return "tile_"+(index < 10 ? "0" : "")+index; }
	public function update(dt:Float):Void {
		var started = MetricClock.now();
		if (configuration.animated) for (model in models) model.update(dt);
		lastAnimationMs = MetricClock.now()-started;
		frame++;
		if (configuration.textureSwap && frame%60 == 0) {
			for (i in 0...models.length) for (mesh in models[i].meshes) {
				if (mesh.name == "Belt") mesh.material.texture = assets.getBitmapData(tile((i+Std.int(frame/60))%20));
				mesh.material.smoothing = Std.int(frame/60)%2 == 0; mesh.material.textureMinSmoothing = null;
			}
		}
		if (probe != null) { previews[0].smoothing = Std.int(frame/30)%2 == 0; previews[1].smoothing = !previews[0].smoothing; probe.afterSmoothing=previews[1].smoothing; }
	}
	public function metadata():Dynamic {
		return {sceneCount:scenes.length,modelCount:models.length,boxCount:boxes.length,
			viewports:[for (scene in scenes) {width:scene.width,height:scene.height,renderScale:scene.renderScale}],
			cameras:[for (scene in scenes) {fieldOfView:scene.camera.fieldOfView,near:scene.camera.near,far:scene.camera.far,
				x:scene.camera.x,y:scene.camera.y,z:scene.camera.z}],
			lighting:[for (scene in scenes) {ambientColor:scene.ambientColor,ambientIntensity:scene.ambientIntensity,
				color:scene.light.color,intensity:scene.light.intensity,shadowBias:scene.light.shadowBias,shadowSlopeBias:scene.light.shadowSlopeBias,
				shadowPadding:scene.light.shadowPadding}],
			sourceTriangles:assets.getModel(configuration.dense ? "robot-dense" : "robot").triangleCount,
			geometryNote:configuration.dense ? "所有网格双权重 CPU 蒙皮" : "躯干双权重，其余网格刚性优化"};
	}
	public function dispose():Void {
		if (probe != null) { probe.dispose(); probe = null; }
		for (scene in scenes) scene.dispose();
		for (geometry in geometries) geometry.dispose();
		for (material in materials) material.dispose();
		for (image in previews) image.data = null;
		if (layer.parent != null) layer.parent.removeChild(layer);
		layer.dispose(); models = []; scenes = []; boxes = []; previews = []; geometries = []; materials = []; assets = null;
	}
}
