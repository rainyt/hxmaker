package;

import hx.layout.AnchorLayoutData;
import hx.layout.AnchorLayout;
import hx.display.FPS;
import hx.display.Stage;
import hx.display.Sprite;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Scene3D;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.PlaneGeometry;
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.material.Material3D;
import hx.material.LambertTextureMaterial;
import hx.events.MouseEvent;

/** 两个独立三维视口夹住二维面板，直接展示显示树的合成顺序。 */
class GameStage extends Stage {
	private var foreground:Scene3D;
	private var panel:Sprite;
	private var backBoxes:Array<MeshObject> = [];
	private var frontBox:MeshObject;
	private var geometries:Array<Geometry3D> = [];
	private var materials:Array<Material3D> = [];
	private var paused:Bool = false;
	private var elapsed:Float = 0;

	override public function onStageInit():Void {
		super.onStageInit();

		var fps = new FPS();
		topView.addChild(fps);
		fps.scale = 0.5;
		fps.layoutData = new AnchorLayoutData(null, 0);
		topView.layout = new AnchorLayout();

		// 添加顺序就是合成顺序：底层三维 → 中层二维 → 透明前景三维。
		var background = createScene(1);
		addChild(background);
		mesh(background, PlaneGeometry.create(18, 12), 0x344960, 0, -1.5, 0);
		for (i in 0...5) {
			// 高低与前后交错，让二维面板上下都露出旋转方块，同时保留局部遮挡。
			var upper = i % 2 == 0;
			backBoxes.push(mesh(background, BoxGeometry.create(1.7, 2.6, 1.7), upper ? 0x518de0 : 0x50c7bc,
				(i - 2) * 2.7, upper ? 1.8 : 0, upper ? -3 : 4));
		}

		panel = new Sprite();
		addChild(panel);
		var card = new Quad(800, 210, 0xf0e7d5);
		card.x = 150;
		card.y = 300;
		panel.addChild(card);
		label(panel, "中层：不透明 2D 面板", 178, 316, 25, 0x26344a);
		label(panel, "面板遮住后方蓝绿色 3D 方块", 178, 358, 20, 0x344960);
		label(panel, "橙色方块来自另一个 Scene3D", 178, 438, 20, 0x344960);
		label(panel, "它可以继续绘制在这张 2D 面板上方", 178, 472, 20, 0x344960);

		// 透明的是视口背景；前景网格保持不透明，以便清楚观察遮挡。
		foreground = createScene(0);
		foreground.mouseEnabled = false;
		addChild(foreground);
		frontBox = mesh(foreground, BoxGeometry.create(2.2, 2.2, 2.2), 0xffa63c, 2, 0, 0);

		label(this, "多个 Scene3D：3D → 2D → 3D（透明背景）", 24, 18, 28, 0xffffff);
		label(this, "蓝绿色：底层场景　米色：二维面板　橙色：前景独立场景", 24, 62, 18, 0xb6c7de);
		action("前景 3D", 24, function() {
			foreground.visible = !foreground.visible;
			return foreground.visible;
		});
		action("中层 2D", 218, function() {
			panel.visible = !panel.visible;
			return panel.visible;
		});
		action("透明背景", 412, function() {
			foreground.backgroundAlpha = foreground.backgroundAlpha == 0 ? 1 : 0;
			return foreground.backgroundAlpha == 0;
		});
		action("旋转动画", 606, function() {
			paused = !paused;
			return !paused;
		});
		label(this, "关闭前景可看完整面板；关闭面板可看后方方块；关闭透明背景可观察视口矩形。", 24, 710, 18, 0xb6c7de);
		updateEnabled = true;
	}

	private function createScene(backgroundAlpha:Float):Scene3D {
		var scene = new Scene3D(1052, 530);
		scene.x = 24;
		scene.y = 160;
		scene.backgroundColor = 0x101c30;
		scene.backgroundAlpha = backgroundAlpha;
		scene.ambientIntensity = 0.5;
		var camera = new Camera3D();
		camera.setPosition(0, 5, 12);
		camera.lookAt(new Vector3D(0, 0, 0));
		scene.root.addChild(camera);
		scene.camera = camera;
		var light = new DirectionalLight3D(0xffffff, 0.8);
		scene.root.addChild(light);
		scene.light = light;
		return scene;
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (paused || frontBox == null)
			return;
		elapsed += dt;
		for (i in 0...backBoxes.length) {
			backBoxes[i].rotationY = elapsed * 25 + i * 15;
		}
		frontBox.rotationY = -elapsed * 40;
		frontBox.rotationX = 20 + Math.sin(elapsed) * 15;
		frontBox.x = 2 + Math.sin(elapsed * 0.7) * 1.2;
	}

	private function action(title:String, x:Float, callback:Void->Bool):Void {
		var button = label(this, title + "：开启", x, 108, 20, 0x8ed6ff);
		button.mouseEnabled = true;
		button.addEventListener(MouseEvent.CLICK, function(_) {
			button.data = title + (callback() ? "：开启" : "：关闭");
		});
	}

	private function label(parent:hx.display.DisplayObjectContainer, text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var result = new Label(text);
		result.x = x;
		result.y = y;
		result.fontSize = size;
		result.color = color;
		parent.addChild(result);
		return result;
	}

	private function mesh(scene:Scene3D, geometry:Geometry3D, color:Int, x:Float, y:Float, z:Float):MeshObject {
		var material = new LambertTextureMaterial(null, color);
		geometries.push(geometry);
		materials.push(material);
		var result = new MeshObject(geometry, material);
		result.setPosition(x, y, z);
		scene.root.addChild(result);
		return result;
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		super.dispose();
		for (geometry in geometries)
			geometry.dispose();
		for (material in materials)
			material.dispose();
		geometries = [];
		materials = [];
		backBoxes = [];
		frontBox = null;
		foreground = null;
		panel = null;
	}
}
