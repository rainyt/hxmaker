package;

import hx.display.FPS;
import hx.display.Label;
import hx.display.Quad;
import hx.events.Event;
import hx.events.KeyboardEvent;
import hx.events.MouseEvent;
import hx.events.TouchEvent;
import hx.geom.Vector3D;

/** 探索界面与输入；模型、碰撞、任务数据由 Blender 世界清单提供。 */
class GameStage extends hx.display.Stage {
	private var world:ExplorerWorld;
	private var keys:Map<Int, Bool> = [];
	private var dragging:Bool = false;
	private var lastX:Float = 0;
	private var lastY:Float = 0;
	private var virtualForward:Float = 0;
	private var virtualStrafe:Float = 0;
	private var title:Label;
	private var objective:Label;
	private var prompt:Label;
	private var story:Label;
	private var position:Label;
	private var help:Label;
	private var mapPlayer:Quad;
	private var mapMarkers:Array<{item:Dynamic, marker:Quad}> = [];
	private var releaseCount:Int = 0;
	private var lastRelease:Dynamic;
	#if js
	private var blurHandler:js.html.Event->Void;
	#end

	override public function onStageInit():Void {
		super.onStageInit();
		startWorld();
		buildHud();
		var fps = new FPS();
		fps.x = 946;
		fps.y = 292;
		fps.scale = 0.5;
		addChild(fps);
		addEventListener(Event.UPDATE, handleFrame);
		addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		addEventListener(MouseEvent.MOUSE_MOVE, onMove);
		addEventListener(MouseEvent.MOUSE_UP, onRelease);
		addEventListener(TouchEvent.TOUCH_MOVE, onMove);
		addEventListener(TouchEvent.TOUCH_END, onRelease);
		addEventListener(TouchEvent.TOUCH_CANCEL, onRelease);
		addEventListener(Event.DEACTIVATE, handleDeactivate);
		#if js
		blurHandler = _ -> clearInput();
		js.Browser.window.addEventListener("blur", blurHandler);
		#end
		#if hxmaker_explorer_checks
		Reflect.setField(js.Browser.window, "__hxmakerExplorer", {state: checkState, command: checkCommand});
		#end
	}

	private function startWorld():Void {
		clearInput();
		if (world != null) {
			world.dispose();
			releaseCount++;
			#if hxmaker_explorer_checks
			lastRelease = {
				sceneDisposed: world.view.isDisposed,
				controllerDisposed: world.controller == null || world.controller.isDisposed,
				collisionDisposed: world.collision.isDisposed,
				colliders: world.collision.colliders.length,
				nodes: world.view.root.children.length
			};
			#end
		}
		world = new ExplorerWorld();
		addChildAt(world.view, 0);
		world.view.addEventListener(MouseEvent.MOUSE_DOWN, onPress);
		world.view.addEventListener(TouchEvent.TOUCH_BEGIN, onPress);
		world.onReady = () -> {
			focus = world.view;
			story.data = world.message;
			rebuildMap();
		};
		world.onMessage = value -> story.data = value;
	}

	private function panel(x:Float, y:Float, w:Float, h:Float, alpha:Float = 0.85):Quad {
		var value = new Quad(w, h, 0x101e2c);
		value.x = x;
		value.y = y;
		value.alpha = alpha;
		value.mouseEnabled = false;
		addChild(value);
		return value;
	}

	private function label(text:String, x:Float, y:Float, size:Int, color:Int = 0xe9f2f8, width:Float = 0):Label {
		var value = new Label(text);
		value.x = x;
		value.y = y;
		value.fontSize = size;
		value.color = color;
		value.mouseEnabled = false;
		if (width > 0)
			value.width = width;
		value.data = text;
		addChild(value);
		return value;
	}

	private function action(text:String, x:Float, y:Float, w:Float, callback:Void->Void):Void {
		var background = panel(x, y, w, 32, 1);
		background.mouseEnabled = true;
		background.addEventListener(MouseEvent.CLICK, _ -> callback());
		label(text, x + 10, y + 6, 14, 0xc8e4e8);
	}

	private function buildHud():Void {
		panel(0, 0, 1120, 70, 1);
		title = label("雪岭观测站", 24, 17, 25, 0xf5ead3);
		label("一段关于山脉与旧世界的探索", 210, 26, 14, 0x9cbbc4);
		action("距离雾 F", 590, 18, 110, () -> world.view.fog.enabled = !world.view.fog.enabled);
		action("保存 K", 710, 18, 100, () -> world.save());
		action("帮助 H", 820, 18, 100, () -> help.visible = !help.visible);
		action("新旅程", 930, 18, 100, () -> world.newJourney());
		action("重试", 1040, 18, 65, () -> {
			if (!world.ready)
				startWorld();
		});
		panel(18, 86, 700, 52, 0.76);
		objective = label("正在接入观测站……", 32, 99, 18, 0xf4dc9d, 670);
		panel(946, 86, 156, 194, 0.9);
		label("观测站地图", 960, 96, 14, 0xe9d5a4);
		panel(958, 123, 132, 140, 1);
		mapPlayer = new Quad(6, 6, 0xfff1b9);
		mapPlayer.mouseEnabled = false;
		addChild(mapPlayer);
		panel(0, 674, 1120, 86, 1);
		prompt = label("正在加载世界资源……", 24, 686, 17, 0xf4dc9d, 920);
		story = label("", 24, 717, 14, 0xc4d5df, 930);
		position = label("", 950, 690, 12, 0x9ab8c5, 160);
		help = label("WASD / 方向键：移动\n拖动场景：环顾\nShift：奔跑　空格：跳跃\nE：附近交互　K：保存\nF：距离雾　R：回到入口\nEsc：停止输入\n触屏可使用下方方向键", 30, 160, 15, 0xe1edf4, 310);
		help.visible = false;
		label("+", 552, 378, 20, 0xf6eedb);
		hold("前", 82, 553, 1, 0);
		hold("左", 24, 603, 0, -1);
		hold("后", 82, 603, -1, 0);
		hold("右", 140, 603, 0, 1);
		action("交互 E", 948, 602, 140, () -> world.interact());
		action("跳跃", 948, 557, 140, () -> world.jump());
	}

	private function hold(text:String, x:Float, y:Float, forward:Float, strafe:Float):Void {
		var button = panel(x, y, 48, 40, 0.75);
		button.mouseEnabled = true;
		var press:MouseEvent->Void = event -> {
			virtualForward = forward;
			virtualStrafe = strafe;
			dragging = false;
		};
		button.addEventListener(MouseEvent.MOUSE_DOWN, press);
		button.addEventListener(TouchEvent.TOUCH_BEGIN, press);
		label(text, x + 15, y + 9, 16);
	}

	private function rebuildMap():Void {
		for (entry in mapMarkers) {
			removeChild(entry.marker);
			entry.marker.dispose();
		}
		mapMarkers = [];
		for (item in world.interactions)
			if (item.kind == "beacon" || item.kind == "gate" || item.kind == "archive") {
				var marker = new Quad(6, 6, item.kind == "beacon" ? 0x68dfe5 : 0xe8ae65);
				marker.x = 958 + (item.position[0] + 31) / 62 * 132 - 3;
				marker.y = 123 + (item.position[2] + 35) / 70 * 140 - 3;
				marker.mouseEnabled = false;
				addChild(marker);
				mapMarkers.push({item: item, marker: marker});
			}
	}

	private function handleFrame(_:Event):Void {
		var forward = (pressed(87) || pressed(38) ? 1 : 0) - (pressed(83) || pressed(40) ? 1 : 0) + virtualForward;
		var strafe = (pressed(68) || pressed(39) ? 1 : 0) - (pressed(65) || pressed(37) ? 1 : 0) + virtualStrafe;
		world.update(hx.core.Hxmaker.engine.dt, forward, strafe, pressed(16));
		if (!world.ready) {
			prompt.data = world.failure != "" ? world.failure + "（点击右上角重试）" : "正在加载观测站、山地和天空……";
			return;
		}
		objective.data = world.complete ? "调查完成 · 观测网络已恢复 · 可以继续探索" : world.collected.length < 3 ? "恢复观测网络　"
			+ world.collected.length
			+ " / 3　·　寻找地图上的青色信标" : world.gateOpen ? "读取核心档案　·　进入北侧档案馆" : "观测网络在线　·　前往北侧档案馆开启闸门";
		prompt.data = world.hint();
		var p = world.controller.position;
		position.data = "位置 " + Math.round(p.x) + "，" + Math.round(p.z) + "\n距离雾：" + (world.view.fog.enabled ? "开启" : "关闭");
		mapPlayer.x = 958 + (p.x + 31) / 62 * 132 - 3;
		mapPlayer.y = 123 + (p.z + 35) / 70 * 140 - 3;
		for (entry in mapMarkers)
			if (entry.item.kind == "beacon")
				entry.marker.alpha = world.collected.indexOf(entry.item.id) >= 0 ? 0.25 : 1;
	}

	private function pressed(code:Int):Bool {
		return keys.get(code) == true;
	}

	private function onKeyDown(event:KeyboardEvent):Void {
		if (pressed(event.keyCode))
			return;
		keys.set(event.keyCode, true);
		switch (event.keyCode) {
			case 69:
				world.interact();
			case 32:
				world.jump();
			case 75:
				world.save();
			case 70:
				world.view.fog.enabled = !world.view.fog.enabled;
			case 72:
				help.visible = !help.visible;
			case 82:
				if (world.ready) {
					world.controller.teleport(new Vector3D(0, 0.05, 27));
					world.yaw = 0;
					world.pitch = -0.02;
				}
			case 27:
				clearInput();
			default:
		}
	}

	private function onKeyUp(event:KeyboardEvent):Void {
		keys.remove(event.keyCode);
	}

	private function onPress(event:MouseEvent):Void {
		if (event.target != world.view)
			return;
		focus = world.view;
		dragging = true;
		lastX = event.stageX;
		lastY = event.stageY;
	}

	private function onMove(event:MouseEvent):Void {
		if (!dragging || !world.ready)
			return;
		world.look((event.stageX - lastX) * 0.004, -(event.stageY - lastY) * 0.004);
		lastX = event.stageX;
		lastY = event.stageY;
	}

	private function onRelease(_:MouseEvent):Void {
		dragging = false;
		virtualForward = virtualStrafe = 0;
	}

	private function handleDeactivate(_:Event):Void {
		clearInput();
	}

	private function clearInput():Void {
		keys.clear();
		dragging = false;
		virtualForward = virtualStrafe = 0;
	}

	#if hxmaker_explorer_checks
	private function checkState():Dynamic {
		var p = world.ready ? world.controller.position : new Vector3D();
		return {
			ready: world.ready,
			failure: world.failure,
			position: [p.x, p.y, p.z],
			yaw: world.yaw,
			pitch: world.pitch,
			collected: world.collected,
			gateOpen: world.gateOpen,
			complete: world.complete,
			grounded: world.ready && world.controller.grounded,
			hint: world.ready ? world.hint() : "",
			fog: world.view.fog.enabled,
			stats: world.view.stats,
			releases: releaseCount,
			lastRelease: lastRelease
		};
	}

	private function checkCommand(name:String, x:Float = 0, z:Float = 0):Void {
		switch (name) {
			case "face":
				world.look(Math.atan2(x - world.controller.position.x, -(z - world.controller.position.z)) - world.yaw, -world.pitch);
			case "teleport":
				world.controller.teleport(new Vector3D(x, 0.05, z));
			case "restart":
				startWorld();
			case "reset":
				world.newJourney();
			default:
				throw "未知探索验收命令";
		}
	}
	#end

	override public function dispose():Void {
		if (isDisposed)
			return;
		clearInput();
		#if js
		js.Browser.window.removeEventListener("blur", blurHandler);
		#end
		#if hxmaker_explorer_checks
		Reflect.deleteField(js.Browser.window, "__hxmakerExplorer");
		#end
		world.dispose();
		super.dispose();
	}
}
