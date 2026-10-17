package;

import hx.display.Stage;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.display.Label;
import hx.display.Scene3D;
import hx.display3d.Billboard3D;
import hx.display3d.Camera3D;
import hx.display3d.Effect3D;
import hx.display3d.MeshObject;
import hx.display3d.Node3D;
import hx.display3d.Ribbon3D;
import hx.display3d.Trail3D;
import hx.display3d.ParticleSystem3D;
import hx.effect3d.FloatCurve3D;
import hx.effect3d.ParticleSettings3D;
import hx.effect3d.SpriteSheet3D;
import hx.effect3d.TrailSettings3D;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.events.Scene3DInputEvent;
import hx.geom.Vector3D;
import hx.geometry.PlaneGeometry;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.material.BlendMode3D;
import hx.material.AnimatedEffectMaterial3D;
import hx.material.Material3D;
import hx.material.EffectMaterial3D;
import hx.material.UnlitTextureMaterial;

/** 无外部素材的粒子、刀光、弹道拖尾和流光溶解示例，点击标题暂停。 */
class Game extends Stage {
	private var source:openfl.display.BitmapData;
	private var atlas:openfl.display.BitmapData;
	private var effect:Effect3D;
	private var smoke:ParticleSystem3D;
	private var impact:ParticleSystem3D;
	private var fireball:Billboard3D;
	private var ring:MeshObject;
	private var time:Float = 0;
	private var paused:Bool = false;
	private var orbit:OrbitCameraController3D;
	private var input:Scene3DInput;
	private var trail:Trail3D;
	private var ribbon:Ribbon3D;
	private var bladeStart:Node3D;
	private var bladeEnd:Node3D;
	private var blade:MeshObject;
	private var surfaceMaterial:AnimatedEffectMaterial3D;
	private var ownedSources:Array<openfl.display.BitmapData> = [];
	private var ownedGeometries:Array<Geometry3D> = [];
	private var ownedMaterials:Array<Material3D> = [];

	override public function onStageInit():Void {
		super.onStageInit();
		var scene = new Scene3D(960, 540); scene.y = 60;
		scene.backgroundAlpha = 1; scene.backgroundColor = 0x17243b;
		addChild(scene);
		var camera = new Camera3D(); scene.root.addChild(camera); scene.camera = camera;
		camera.lookFrom(new Vector3D(0, 4, 9), new Vector3D(0, 0, 0));
		orbit = new OrbitCameraController3D(camera, new Vector3D(0, 0, 0));
		orbit.minDistance = 3; orbit.maxDistance = 20;
		orbit.minPitch = -75; orbit.maxPitch = 80;
		input = new Scene3DInput(scene, orbit);
		var floor = new MeshObject(PlaneGeometry.create(14, 9), new UnlitTextureMaterial(null, 0x26334a));
		floor.y = -1; scene.root.addChild(floor);

		source = radial(64, false);
		atlas = new openfl.display.BitmapData(128, 128, true, 0);
		// 四帧程序化爆炸图集；直接写入像素，示例无需加载外部素材。
		for (frame in 0...4) {
			var tile = radial(64, false, 0.35 + frame * 0.2);
			atlas.copyPixels(tile, tile.rect, new openfl.geom.Point((frame % 2) * 64, Std.int(frame / 2) * 64));
			tile.dispose();
		}
		var texture = OpenFlBitmapData.fromBitmapData(source);
		effect = new Effect3D(); scene.root.addChild(effect);
		var settings = new ParticleSettings3D();
		settings.duration = 1.2; settings.emissionRate = 70; settings.maxParticles = 160;
		settings.speedMin = 0.1; settings.speedMax = 0.3;
		settings.gravity.setTo(0, 0.5, 0); settings.lifetimeMin = 0.5; settings.lifetimeMax = 1.1;
		settings.sizeMin = 0.15; settings.sizeMax = 0.3;
		settings.size = new FloatCurve3D([0., 1.], [0.5, 2.5]);
		settings.alpha = new FloatCurve3D([0., 1.], [0.45, 0.]);
		smoke = effect.addEmitter(new ParticleSystem3D(new EffectMaterial3D(texture, BlendMode3D.NORMAL, 0xa8b6ca), settings));
		smoke.y = 0.3;

		var explosion = new ParticleSettings3D();
		explosion.emissionRate = 0; explosion.burst = 90; explosion.duration = 0.01;
		explosion.coneAngle = 180; explosion.speedMin = 1; explosion.speedMax = 3;
		explosion.gravity.setTo(0, -0.6, 0); explosion.lifetimeMin = 0.35; explosion.lifetimeMax = 0.8;
		explosion.sheet = new SpriteSheet3D(2, 2);
		explosion.green = new FloatCurve3D([0., 1.], [0.9, 0.15]);
		explosion.blue = FloatCurve3D.constant(0.1);
		impact = effect.addEmitter(new ParticleSystem3D(new EffectMaterial3D(OpenFlBitmapData.fromBitmapData(atlas), BlendMode3D.ADD), explosion), 1.2);
		impact.setPosition(3, 0.3, 0);

		fireball = new Billboard3D(new EffectMaterial3D(texture, BlendMode3D.ADD, 0xffa536));
		fireball.billboardWidth = fireball.billboardHeight = 0.7; fireball.y = 0.3;
		scene.root.addChild(fireball);
		var ringSource = radial(64, true);
		ring = new MeshObject(PlaneGeometry.create(2.5, 2.5), new EffectMaterial3D(OpenFlBitmapData.fromBitmapData(ringSource), BlendMode3D.ADD, 0x399dff));
		ring.y = -0.98; scene.root.addChild(ring);
		// 第二阶段：弹道拖尾和双端刀光与粒子共用组合时间轴。
		var trailSettings = new TrailSettings3D();
		trailSettings.width = 0.22; trailSettings.lifetime = 0.35;
		trail = new Trail3D(new EffectMaterial3D(texture, BlendMode3D.ADD, 0xff912e), trailSettings);
		trail.target = fireball; effect.addRibbon(trail, 0, 1.2);
		bladeStart = new Node3D(); bladeEnd = new Node3D();
		scene.root.addChild(bladeStart); scene.root.addChild(bladeEnd);
		var ribbonSettings = new TrailSettings3D();
		ribbonSettings.lifetime = 0.3; ribbonSettings.widthOverLife = FloatCurve3D.constant(1);
		ribbon = new Ribbon3D(new EffectMaterial3D(texture, BlendMode3D.ADD, 0x56ccff), ribbonSettings);
		ribbon.startNode = bladeStart; ribbon.endNode = bladeEnd; effect.addRibbon(ribbon, 0, 0.95);
		blade = new MeshObject(BoxGeometry.create(0.04, 1.4, 0.04), new UnlitTextureMaterial(null, 0xd9f5ff));
		scene.root.addChild(blade);

		// 主贴图与噪声都取自图集左半区域，右半放哨兵色方便观察串色。
		var flowSource = pattern(false), noiseSource = pattern(true);
		var flowTexture = OpenFlBitmapData.fromBitmapData(flowSource).sub(0, 0, 64, 64);
		var noiseTexture = OpenFlBitmapData.fromBitmapData(noiseSource).sub(0, 0, 64, 64);
		surfaceMaterial = new AnimatedEffectMaterial3D(flowTexture, BlendMode3D.ADD, 0x388bff);
		surfaceMaterial.maskTexture = OpenFlBitmapData.fromBitmapData(ringSource);
		surfaceMaterial.noiseTexture = noiseTexture;
		surfaceMaterial.uvSpeedV = -0.3; surfaceMaterial.uvScaleU = 2;
		surfaceMaterial.distortion = 0.08; surfaceMaterial.edgeColor = 0x8eeeff;
		var portal = new MeshObject(PlaneGeometry.create(2.8, 2.8), surfaceMaterial);
		portal.rotationX = 90; portal.setPosition(0, 1.0, -2.0); scene.root.addChild(portal);
		ownedSources = [source, atlas, ringSource, flowSource, noiseSource];
		collectResources(scene.root);

		var title = new Label("三维特效：拖尾 / 刀光 / 流光溶解；点击暂停");
		title.x = 20; title.y = 18; title.fontSize = 20; title.color = 0xffffff; addChild(title);
		title.addEventListener(MouseEvent.CLICK, function(_) { paused = !paused; });
		input.addEventListener(Scene3DInputEvent.SELECT, function(_) {
			scene.backgroundAlpha = scene.backgroundAlpha == 0 ? 1 : 0;
			scene.requestRender();
		});
		var status = new Label(""); status.x = 20; status.y = 608; status.fontSize = 16; status.color = 0xffffff;
		addChild(status);
		effect.play();
		scene.addEventListener(Event.UPDATE, function(_) {
			// 相机独立于特效暂停更新，先转镜头，再重建粒子和广告牌朝向。
			var frameDt = Hxmaker.engine.dt;
			orbit.update(frameDt);
			var dt = paused ? 0 : frameDt;
			time += dt;
			if (time >= 3.2) { time = 0; effect.play(); }
			var x = -3 + Math.min(1.2, time) * 5;
			smoke.x = x; fireball.x = x; fireball.visible = time < 1.2;
			// 先更新刀光两端和目标，再推进组合轨道，最后更新广告牌。
			var angle = -1.3 + Math.min(0.95, time) / 0.95 * 2.6;
			bladeStart.setPosition(-1.7 + Math.sin(angle) * 0.25, 0.3 + Math.cos(angle) * 0.25, 1.2);
			bladeEnd.setPosition(-1.7 + Math.sin(angle) * 1.65, 0.3 + Math.cos(angle) * 1.65, 1.2);
			blade.setPosition(-1.7 + Math.sin(angle) * 0.95, 0.3 + Math.cos(angle) * 0.95, 1.2);
			blade.rotationZ = -angle * 180 / Math.PI; blade.visible = time < 0.95;
			surfaceMaterial.dissolve = Math.max(0, Math.min(1, (time - 0.7) / 1.8));
			surfaceMaterial.update(dt);
			effect.paused = paused; effect.update(dt, camera); fireball.update(camera);
			ring.rotationY += dt * 35;
			ring.material.opacity = 0.5 + Math.sin(time * 4) * 0.2;
			status.data = "粒子：" + (smoke.particleCount + impact.particleCount) + "　轨迹截面：" + (trail.sectionCount + ribbon.sectionCount) + "　批次：" + scene.stats.drawCalls
				+ "　拖动旋转 / 滚轮缩放 / 轻点切换背景";
		});
	}

	/** 先解除视口输入和指针捕获，再释放相机控制器及舞台。 */
	override public function dispose():Void {
		if (isDisposed) return;
		if (input != null) input.dispose();
		if (orbit != null) orbit.dispose();
		super.dispose();
		for (geometry in ownedGeometries) if (!geometry.isDisposed && geometry.referenceCount == 0) geometry.dispose();
		for (material in ownedMaterials) if (!material.isDisposed && material.referenceCount == 0) material.dispose();
		for (bitmap in ownedSources) bitmap.dispose();
		ownedGeometries = []; ownedMaterials = []; ownedSources = [];
	}

	/** 示例中全部网格资源均由本舞台创建，销毁节点后统一释放。 */
	private function collectResources(node:Node3D):Void {
		if (Std.isOfType(node, MeshObject)) {
			var mesh:MeshObject = cast node;
			if (mesh.geometry != null && ownedGeometries.indexOf(mesh.geometry) < 0) ownedGeometries.push(mesh.geometry);
			if (mesh.material != null && ownedMaterials.indexOf(mesh.material) < 0) ownedMaterials.push(mesh.material);
		}
		for (child in node.children) collectResources(child);
	}

	private function pattern(noise:Bool):openfl.display.BitmapData {
		var bitmap = new openfl.display.BitmapData(128, 64, true, 0xffff00ff);
		for (y in 0...64) for (x in 0...64) {
			var u = x / 64, v = y / 64;
			var value = noise ? 0.5 + Math.sin(u * Math.PI * 8 + Math.sin(v * Math.PI * 4)) * 0.25
				+ Math.cos(v * Math.PI * 6 - u * Math.PI * 4) * 0.25
				: 0.25 + Math.pow(0.5 + Math.sin(v * Math.PI * 12 + Math.sin(u * Math.PI * 4)) * 0.5, 3) * 0.75;
			var channel = Std.int(Math.max(0, Math.min(1, value)) * 255);
			bitmap.setPixel32(x, y, 0xff000000 | (channel << 16) | (channel << 8) | channel);
		}
		return bitmap;
	}

	private function radial(size:Int, ring:Bool, spread:Float = 1):openfl.display.BitmapData {
		var bitmap = new openfl.display.BitmapData(size, size, true, 0);
		for (y in 0...size) for (x in 0...size) {
			var dx = (x + 0.5) / size * 2 - 1, dy = (y + 0.5) / size * 2 - 1;
			var r = Math.sqrt(dx * dx + dy * dy);
			var alpha = ring ? Math.max(0, 1 - Math.abs(r - 0.7) / 0.09) : Math.pow(Math.max(0, 1 - r / spread), 2);
			bitmap.setPixel32(x, y, (Std.int(alpha * 255) << 24) | 0xffffff);
		}
		return bitmap;
	}
}
