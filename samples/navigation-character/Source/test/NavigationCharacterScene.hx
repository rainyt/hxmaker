package test;

#if hxmaker_navigation_checks
import NavigationAgentChecks;
#end
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
import hx.navigation3d.NavAgent3D;
import hx.navigation3d.NavAgentState3D;
import hx.navigation3d.NavGraph3D;
import hx.navigation3d.NavNode3D;
import hx.navigation3d.NavEdge3D;
import hx.geometry.BoxGeometry;
import hx.geometry.RampGeometry;
import hx.geometry.Geometry3D;
import hx.light.DirectionalLight3D;
import hx.material.CullMode3D;
import hx.material.LambertTextureMaterial;
import hx.material.Material3D;

/** 纯 hxmaker 验收场景；更新顺序为控制器、角色动画、相机，不修改原有输入语义。 */
class NavigationCharacterScene extends Scene {
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
	private var agent:NavAgent3D;
	private var graph:NavGraph3D = new NavGraph3D();
	private var routes:Array<Array<NavNode3D>> = [];
	private var doorEdges:Array<NavEdge3D> = [];
	private var door:BoxCollider3D;
	private var doorMesh:MeshObject;
	private var doorOpen:Bool = true;
	private var status:Label;
	private var detail:Label;
	private var doorLabel:Label;
	private var lastAction:String = "资源加载中……";
	private var elapsed:Float = 0;
	private var inputStage:Stage;
	private var spaceHeld:Bool = false;
	private var updates:Int = 0;
	private var pathMarkers:Array<MeshObject> = [];
	private var markerGeometry:Geometry3D;
	private var markerMaterial:Material3D;
	private var shownPath:hx.navigation3d.NavPath3D;

	override public function onStageInit():Void {
		super.onStageInit();
		updateEnabled = true;
		sceneBackground.data = 0x172033;
		sceneBackground.alpha = 1;
		label("角色导航 · A* / 门开关 / 楼梯 / 坡道", 24, 18, 25, 0xffffff);
		action("穿门 / 绕墙", 24, 65, function() {
			scenario(0, false);
		});
		action("上楼梯", 240, 65, function() {
			scenario(1, false);
		});
		action("下楼梯", 420, 65, function() {
			scenario(1, true);
		});
		action("上坡道", 600, 65, function() {
			scenario(2, false);
		});
		action("下坡道", 780, 65, function() {
			scenario(2, true);
		});
		doorLabel = action("门：开", 24, 105, function() {
			setDoor(!doorOpen);
		});
		action("暂停 / 继续", 240, 105, function() {
			if (agent != null) {
				if (agent.state == NavAgentState3D.PAUSED)
					agent.resume();
				else
					agent.pause();
			}
		});
		action("不可达目标", 470, 105, function() {
			if (agent != null) {
				scenario(0, false);
				agent.setDestination(routes[3][0]);
				lastAction = "封闭高台无连接，应报告目标不可达";
			}
		});
		action("停止", 730, 105, function() {
			if (agent != null)
				agent.stop();
		});
		view = new Scene3D(1072, 490);
		view.x = 24;
		view.y = 150;
		view.backgroundColor = 0x26384c;
		view.backgroundAlpha = 1;
		view.ambientIntensity = 0.4;
		view.profilingEnabled = true;
		addChild(view);
		var camera = new Camera3D();
		view.root.addChild(camera);
		view.camera = camera;
		var light = new DirectionalLight3D(0xffffff, 0.8);
		light.direction = new Vector3D(-1, -2, -1);
		light.shadowEnabled = true;
		view.root.addChild(light);
		view.light = light;
		cameraControl = new OrbitCameraController3D(camera, new Vector3D(0, 1.2, 0));
		cameraControl.yaw = 15;
		cameraControl.pitch = 50;
		cameraControl.distance = 33;
		cameraControl.minPitch = 10;
		cameraControl.maxDistance = 45;
		cameraControl.snap();
		input = new Scene3DInput(view, cameraControl);
		input.addEventListener(Scene3DInputEvent.SELECT, onSelect);
		box("地面", 34, 1, 26, 0, -0.5, 0, 0x637c89);
		box("墙左", 3.8, 3, 0.6, -12.1, 1.5, 0, 0xb89465);
		box("墙右", 3.8, 3, 0.6, -5.9, 1.5, 0, 0xb89465);
		box("动态门", 2.4, 3, 0.6, -9, 1.5, 0, 0xd57e62);
		door = cast colliders[colliders.length - 1];
		doorMesh = cast door.node;
		setDoor(true);
		for (i in 0...4)
			box("台阶 " + (i + 1), 3, (i + 1) * 0.4, 1.2, -1, (i + 1) * 0.2, -3.4 + i * 1.2, 0xb89465);
		box("楼梯平台", 3, 1.6, 2.4, -1, 0.8, 2, 0xb89465);
		ramp("缓坡", 3, 2.2, 6, 6, 0, -1, 0, 0x71aa83);
		box("坡道平台", 3, 2.2, 2, 6, 1.1, 3, 0x71aa83);
		box("不可达高台", 3, 3, 3, 12, 1.5, 3, 0xc57869);
		buildGraph();
		markerGeometry = BoxGeometry.create(0.15, 0.05, 0.15);
		markerMaterial = new LambertTextureMaterial(null, 0xffda61);
		geometries.push(markerGeometry);
		materials.push(markerMaterial);
		status = label("通过 Assets 加载带贴图角色……", 24, 656, 15, 0xd7e3fc);
		detail = label("", 24, 688, 14, 0xa9bad6);
		label("轻点路点附近：指定目标；左键拖动、滚轮：镜头；Esc：停止；空格：暂停 / 继续。", 24, 720, 14, 0xa9bad6);
		label("黄点显示规划路线。门关闭后走墙左侧；高台不连通。碰撞持续受阻会停止并反馈原因。", 24, 751, 14, 0xa9bad6);
		inputStage = stage;
		inputStage.addEventListener(Event.DEACTIVATE, onDeactivate);
		inputStage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		inputStage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

		stage.focus = view;
		#if hxmaker_navigation_checks
		NavigationAgentChecks.run();
		#end
		load();
	}

	private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
		var value = new Label(text);
		value.x = x;
		value.y = y;
		value.fontSize = size;
		value.color = color;
		value.mouseEnabled = false;
		addChild(value);
		return value;
	}

	private function action(text:String, x:Float, y:Float, callback:Void->Void):Label {
		var value = label(text, x, y, 17, 0x8ed6ff);
		value.mouseEnabled = true;
		value.addEventListener(MouseEvent.CLICK, function(event:MouseEvent) {
			callback();
			#if hxmaker_navigation_checks
			trace("HXMAKER_NAV_ACTION " + text + " " + (agent == null ? "loading" : Std.string(agent.state)));
			#end
			if (view != null)
				stage.focus = view;
			event.preventDefault();
		});
		return value;
	}

	private function visual(width:Float, height:Float, depth:Float, color:Int):MeshObject {
		var geometry = BoxGeometry.create(width, height, depth),
			material = new LambertTextureMaterial(null, color);
		material.cullMode = CullMode3D.NONE;
		geometries.push(geometry);
		materials.push(material);
		var mesh = new MeshObject(geometry, material);
		mesh.pickable = false;
		mesh.castShadow = true;
		view.root.addChild(mesh);
		return mesh;
	}

	private function box(name:String, width:Float, height:Float, depth:Float, x:Float, y:Float, z:Float, color:Int, layer:Int = 1):Void {
		var mesh = visual(width, height, depth, color);
		mesh.name = name;
		mesh.setPosition(x, y, z);
		var collider = new BoxCollider3D(width, height, depth, mesh);
		collider.name = name;
		collider.layer = layer;
		colliders.push(collider);
		world.add(collider);
	}

	private function load():Void {
		var request = new Assets();
		assets = request;
		request.tryLoadTimes = 0;
		request.loadGlb("assets/robot.glb");
		request.onError(error -> {
			request.stop();
			request.clean();
			if (!isDisposed) {
				status.data = "加载失败：" + error.error + "；可点击底部重新进入";
				trace(status.data);
			}
		});
		request.onComplete(_ -> {
			if (isDisposed) {
				request.clean();
				return;
			}
			try {
				var source = request.getGlb("robot");
				if (source == null || !source.texturesReady)
					throw "GLB 或贴图未准备好";
				model = source.createInstance(-1, {lightingEnabled: true});
				model.setScale(0.6, 0.6, 0.6);
				view.root.addChild(model);
				for (mesh in model.meshes)
					mesh.castShadow = true;
				model.animation.play("Idle");
				controller = new CharacterController3D(world, model, 0.35, 1.9);
				controller.stepOffset = 0.45;
				controller.maxSlopeAngle = 45;
				controller.groundSnapDistance = 0.45;
				agent = new NavAgent3D(graph, controller);
				scenario(0, false);
				#if hxmaker_navigation_checks
				NavigationSampleChecks.run(this);
				#end
			} catch (error:Dynamic) {
				if (controller != null) {
					controller.dispose();
					controller = null;
				}
				if (model != null) {
					model.dispose();
					model = null;
				}
				request.clean();
				status.data = "创建失败：" + Std.string(error);
				trace(status.data);
			}
		});
		request.start();
	}

	private function route(points:Array<Vector3D>):Array<NavNode3D> {
		var nodes = [for (point in points) graph.addNode(point)];
		for (i in 1...nodes.length)
			graph.connectBoth(nodes[i - 1], nodes[i]);
		return nodes;
	}

	private function buildGraph():Void {
		var front = graph.addNode(new Vector3D(-9, 0.002, -1.8)),
			back = graph.addNode(new Vector3D(-9, 0.002, 1.8));
		var start = graph.addNode(new Vector3D(-9, 0.002, -6)),
			goal = graph.addNode(new Vector3D(-9, 0.002, 6));
		graph.connectBoth(start, front);
		graph.connectBoth(back, goal);
		doorEdges = graph.connectBoth(front, back);
		var leftFront = graph.addNode(new Vector3D(-15, 0.002, -1.8)),
			leftBack = graph.addNode(new Vector3D(-15, 0.002, 1.8));
		graph.connectBoth(front, leftFront);
		graph.connectBoth(leftFront, leftBack);
		graph.connectBoth(leftBack, back);
		routes.push([start, goal]);
		routes.push(route([
			new Vector3D(-1, 0.002, -6),
			new Vector3D(-1, 0.002, -4.8),
			new Vector3D(-1, 0.402, -3.4),
			new Vector3D(-1, 0.802, -2.2),
			new Vector3D(-1, 1.202, -1),
			new Vector3D(-1, 1.602, 0.2),
			new Vector3D(-1, 1.602, 2)
		]));
		routes.push(route([
			new Vector3D(6, 0.002, -6),
			new Vector3D(6, 0.002, -4.5),
			new Vector3D(6, 0.405, -2.9),
			new Vector3D(6, 1.102, -1),
			new Vector3D(6, 1.835, 1),
			new Vector3D(6, 2.202, 3)
		]));
		routes.push([graph.addNode(new Vector3D(12, 3.002, 3), "不可达高台")]);
	}

	private function setDoor(open:Bool):Void {
		doorOpen = open;
		if (door != null) {
			door.enabled = !open;
			doorMesh.visible = !open;
		}
		for (edge in doorEdges)
			edge.enabled = open;
		if (doorLabel != null)
			doorLabel.data = open ? "门：开" : "门：关";
		lastAction = open ? "门已打开" : "门已关闭，活动路线将在下次更新重规划";
	}

	private function scenario(index:Int, reverse:Bool):Void {
		if (agent == null)
			return;
		var nodes = routes[index],
			start = reverse ? nodes[nodes.length - 1] : nodes[0],
			goal = reverse ? nodes[0] : nodes[nodes.length - 1];
		agent.stop();
		controller.teleport(start.position);
		controller.update(0, new Vector3D());
		agent.setDestination(goal, start);
		lastAction = "已指定" + (reverse ? "返回" : "前进") + "路线";
	}

	private function showPath():Void {
		if (shownPath == agent.path)
			return;
		shownPath = agent.path;
		for (mesh in pathMarkers)
			mesh.dispose();
		pathMarkers = [];
		if (shownPath == null)
			return;
		var points = shownPath.points;
		for (i in 0...points.length) {
			var a = points[i], b = i + 1 < points.length ? points[i + 1] : a;
			var count = Std.int(Math.ceil(b.subtract(a).length / 0.5));
			if (count < 1)
				count = 1;
			for (j in 0...count) {
				var f = j / count, mesh = new MeshObject(markerGeometry, markerMaterial);
				mesh.pickable = false;
				mesh.setPosition(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f + 0.05, a.z + (b.z - a.z) * f);
				view.root.addChild(mesh);
				pathMarkers.push(mesh);
			}
		}
	}

	private function ramp(name:String, width:Float, height:Float, depth:Float, x:Float, y:Float, z:Float, yaw:Float, color:Int):Void {
		var geometry = RampGeometry.create(width, height, depth),
			material = new LambertTextureMaterial(null, color);
		material.cullMode = CullMode3D.NONE;
		geometries.push(geometry);
		materials.push(material);
		var mesh = new MeshObject(geometry, material);
		mesh.name = name;
		mesh.pickable = false;
		mesh.castShadow = true;
		mesh.setPosition(x, y, z);
		mesh.rotationY = yaw;
		view.root.addChild(mesh);
		var collider = new RampCollider3D(width, height, depth, mesh);
		collider.name = name;
		colliders.push(collider);
		world.add(collider);
	}

	private function onSelect(event:Scene3DInputEvent):Void {
		#if hxmaker_navigation_checks
		trace("HXMAKER_NAV_SELECT");
		#end
		if (agent == null)
			return;
		var hit = world.raycast(event.ray, 100, 1);
		if (hit == null || hit.surfaceNormal.y <= 0)
			return;
		var node = graph.nearest(hit.point, 1.8, candidate -> Math.abs(candidate.position.y - hit.point.y) < 0.3);
		if (node == null) {
			lastAction = "点击处附近没有路点，请点击黄点附近或使用路线按钮";
			return;
		}
		agent.setDestination(node);
		lastAction = "目标路点：" + node.id;
	}

	private function onKeyDown(event:KeyboardEvent):Void {
		var before = agent == null ? NavAgentState3D.IDLE : agent.state;
		if (agent == null)
			return;
		if (event.keyCode == Keyboard.ESCAPE)
			agent.stop();
		if (event.keyCode == Keyboard.SPACE && !spaceHeld) {
			spaceHeld = true;
			if (agent.state == NavAgentState3D.PAUSED)
				agent.resume();
			else
				agent.pause();
		}
		#if hxmaker_navigation_checks
		if (before != agent.state)
			trace("HXMAKER_NAV_KEY " + event.keyCode + " " + agent.state);
		#end
	}

	private function onKeyUp(event:KeyboardEvent):Void {
		if (event.keyCode == Keyboard.SPACE)
			spaceHeld = false;
	}

	private function onDeactivate(event:Event):Void {
		spaceHeld = false;
		if (agent != null)
			agent.pause();
	}

	private function round(value:Float):Float {
		return Math.round(value * 100) / 100;
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (isDisposed || view == null)
			return;
		if (agent != null && dt > 0) {
			var result = agent.update(dt);
			updates++;
			var movement = result.displacement,
				moved = Math.sqrt(movement.x * movement.x + movement.z * movement.z);
			if (moved > 1e-5)
				model.rotationY = Math.atan2(movement.x, movement.z) * 180 / Math.PI;
			var clip = moved > 1e-5 ? "Walk" : "Idle";
			if (model.animation.currentName != clip)
				model.animation.crossFade(clip, 0.2);
			model.update(dt);
			showPath();
			elapsed += dt;
			if (elapsed >= 0.15) {
				elapsed = 0;
				var p = controller.position;
				status.data = "状态：" + agent.state + "　脚底 " + round(p.x) + " / " + round(p.y) + " / " + round(p.z) + "　路径点=" + agent.waypointIndex + "　图版本="
					+ graph.revision;
				detail.data = (agent.failureReason != "" ? agent.failureReason : lastAction)
					+ (agent.path == null ? "" : "　搜索展开=" + agent.path.visitedCount + "　成本=" + round(agent.path.cost));
			}
		}
		cameraControl.update(dt);
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		if (inputStage != null) {
			inputStage.removeEventListener(Event.DEACTIVATE, onDeactivate);
			inputStage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			inputStage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		}
		if (agent != null)
			agent.dispose();
		graph.dispose();
		if (input != null)
			input.dispose();
		if (cameraControl != null)
			cameraControl.dispose();
		if (controller != null)
			controller.dispose();
		for (collider in colliders)
			collider.dispose();
		world.dispose();
		if (model != null)
			model.dispose();
		super.dispose();
		var geometryReferences = 0, materialReferences = 0;
		for (geometry in geometries)
			geometryReferences += geometry.referenceCount;
		for (material in materials)
			materialReferences += material.referenceCount;
		for (geometry in geometries)
			geometry.dispose();
		for (material in materials)
			material.dispose();
		if (assets != null) {
			assets.stop();
			assets.clean();
		}
		trace("HXMAKER_NAV_RELEASE " + haxe.Json.stringify({
			worldDisposed: world.isDisposed,
			agentDisposed: agent == null || agent.isDisposed,
			graphDisposed: graph.isDisposed,
			colliders: world.colliders.length,
			updates: updates,
			controllerDisposed: controller == null || controller.isDisposed,
			inputDisposed: input == null || input.isDisposed,
			geometryReferences: geometryReferences,
			materialReferences: materialReferences
		}));
		colliders = [];
		geometries = [];
		materials = [];
		pathMarkers = [];
		inputStage = null;
	}
}
