package;

import hx.assets.Assets;
import hx.assets.AssetObject;
import hx.display.Box;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Spine;
import hx.display.SpineSprite;
import hx.display.Stage;
import hx.display.TextFormat;
import hx.events.Event;
import hx.events.FutureErrorEvent;
import hx.events.MouseEvent;
import hx.events.SpineEvent;
import spine.SkeletonData;

/** 通过引擎资源入口演示 3.8 网格、裁剪、皮肤、事件及插槽挂载。 */
class GameStage extends Stage {
	private var assets:Assets;
	private var character:Spine;
	private var goblin:SpineSprite;
	private var marker:Quad;
	private var status:Label;
	private var eventLog:Label;
	private var messages:Array<String> = [];
	private var skinNames:Array<String> = ["goblin", "goblingirl"];
	private var skinIndex:Int = 0;
	private var loop:Bool = true;
	private var animationName:String = "walk";
	private var eventCount:Int = 0;

	override public function onStageInit():Void {
		super.onStageInit();
		addText("Spine 3.8 · 双库自动适配示例", 24, 20, 1052, 38, 28, 0xffffff);
		addText("运行时：" + Spine.runtimeName + "  /  库版本固定为 3.8.2  /  官方资源导出版本 3.8.55", 24, 66, 1052, 28);
		addPanel(24, "Spine：动画、网格与裁剪");
		addPanel(562, "SpineSprite：皮肤与头部插槽挂载");
		status = addText("正在加载官方示例资源……", 24, 566, 1052, 32, 16, 0x93b3dc);
		eventLog = addText("动画事件将在这里显示。", 24, 722, 1052, 88, 14, 0x93b3dc);
		eventLog.wordWrap = true;
		addAction("待机", 24, 612, () -> playCharacter("idle"));
		addAction("行走", 202, 612, () -> playCharacter("walk"));
		addAction("奔跑", 380, 612, () -> playCharacter("run"));
		addAction("跳跃（单次）", 558, 612, () -> playCharacter("jump", false));
		addAction("传送门（裁剪）", 736, 612, () -> playCharacter("portal", false));
		addAction("停止", 914, 612, () -> {
			character.stop();
			goblin.stop();
			showStatus("已停止，保留当前姿势；点击动作可重新播放。");
		});
		addAction("切换皮肤", 24, 664, () -> {
			skinIndex = (skinIndex + 1) % skinNames.length;
			goblin.setSkinByName(skinNames[skinIndex]);
			goblin.play("walk");
			showStatus("当前皮肤：" + skinNames[skinIndex]);
		});
		addAction("显示 / 隐藏挂点", 202, 664, () -> {
			marker.visible = !marker.visible;
			showStatus("头部挂点：" + (marker.visible ? "显示" : "隐藏"));
		});
		addAction("切换 30 / 60 FPS", 380, 664, () -> {
			var fps:Int = character.renderFps == 60 ? 30 : 60;
			character.renderFps = goblin.renderFps = fps;
			showStatus("骨骼刷新帧率：" + fps);
		});
		addAction("循环开 / 关", 558, 664, () -> {
			loop = !loop;
			playCharacter(animationName);
		});
		addAction("重置", 736, 664, resetCharacters);
		addAction("清空日志", 914, 664, () -> {
			messages.resize(0);
			eventCount = 0;
			eventLog.data = "日志已清空。";
		});
		assets = new Assets();
		assets.tryLoadTimes = 0;
		assets.loadSpineAtlas("assets/spineboy.png", "assets/spineboy.atlas");
		assets.loadString("assets/spineboy-pro.json");
		assets.loadSpineAtlas("assets/goblins.png", "assets/goblins.atlas");
		assets.loadString("assets/goblins-pro.json");
		assets.onError((event:FutureErrorEvent) -> showStatus("资源加载失败：" + event.error));
		assets.onComplete((result:AssetObject<Assets>) -> createCharacters());
		assets.start();
	}

	private function createCharacters():Void {
		try {
			var characterData:SkeletonData = assets.getSkeletonData("spineboy", "spineboy-pro");
			var goblinData:SkeletonData = assets.getSkeletonData("goblins", "goblins-pro");
			character = new Spine(characterData);
			character.x = 284;
			character.y = 540;
			character.scaleX = character.scaleY = 0.5;
			addChild(character);
			goblin = new SpineSprite(goblinData);
			goblin.x = 816;
			goblin.y = 540;
			goblin.scaleX = goblin.scaleY = 0.8;
			addChild(goblin);
			marker = new Quad(18, 18, 0xffd166);
			marker.mouseEnabled = false;
			goblin.bindSlot("head", marker);
			for (type in [SpineEvent.START, SpineEvent.INTERRUPT, SpineEvent.END, SpineEvent.DISPOSE, SpineEvent.EVENT, Event.COMPLETE]) {
				character.addEventListener(type, (event:SpineEvent) -> recordEvent("Spine", event));
				goblin.addEventListener(type, (event:SpineEvent) -> recordEvent("SpineSprite", event));
			}
			resetCharacters();
		} catch (error:Dynamic) {
			showStatus("骨骼初始化失败：" + Std.string(error));
		}
	}

	private function resetCharacters():Void {
		character.stop();
		goblin.stop();
		character.skeleton.setToSetupPose();
		goblin.skeleton.setToSetupPose();
		skinIndex = 0;
		loop = true;
		marker.visible = true;
		character.renderFps = goblin.renderFps = 60;
		goblin.setSkinByName(skinNames[skinIndex]);
		goblin.play("walk");
		playCharacter("walk");
	}

	private function playCharacter(name:String, ?forceLoop:Bool):Void {
		animationName = name;
		var shouldLoop:Bool = forceLoop == null ? loop : forceLoop;
		character.play(name, 0, shouldLoop);
		showStatus("动作：" + name + "  /  " + (shouldLoop ? "循环" : "单次") + "  /  皮肤：" + skinNames[skinIndex]);
	}

	private function recordEvent(source:String, event:SpineEvent):Void {
		var animation:String = event.trackEntry == null ? "" : event.trackEntry.animation.name;
		var detail:String = event.event == null ? "" : " / " + event.event.getData().name;
		eventCount++;
		messages.unshift(eventCount + ". " + source + " / " + event.type + " / " + animation + detail);
		if (messages.length > 4)
			messages.pop();
		eventLog.data = messages.join("\n");
	}

	private function showStatus(message:String):Void {
		status.data = message;
	}

	private function addPanel(x:Float, title:String):Void {
		var panel:Quad = new Quad(514, 438, 0x202c3d);
		panel.x = x;
		panel.y = 112;
		addChild(panel);
		addText(title, x + 18, 124, 478, 28, 17, 0xffffff);
		var ground:Quad = new Quad(478, 2, 0x465973);
		ground.x = x + 18;
		ground.y = 540;
		addChild(ground);
	}

	private function addText(text:String, x:Float, y:Float, width:Float, height:Float, size:Int = 16, color:UInt = 0xbcc9db):Label {
		var label:Label = new Label(text, new TextFormat(null, size, color));
		label.x = x;
		label.y = y;
		label.width = width;
		label.height = height;
		label.wordWrap = false;
		label.mouseEnabled = false;
		addChild(label);
		return label;
	}

	private function addAction(text:String, x:Float, y:Float, action:Void->Void):Void {
		var button:Box = new Box();
		button.x = x;
		button.y = y;
		button.width = 162;
		button.height = 38;
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		button.background = new Quad(162, 38, 0x34435a);
		var label:Label = new Label(text, new TextFormat(null, 15, 0xffffff));
		label.width = 162;
		label.height = 38;
		label.horizontalAlign = CENTER;
		label.verticalAlign = MIDDLE;
		button.addChild(label);
		button.addEventListener(MouseEvent.CLICK, (event:MouseEvent) -> {
			event.bubbling = false;
			if (character == null || goblin == null || marker == null)
				return;
			try {
				action();
			} catch (error:Dynamic) {
				showStatus("操作失败：" + Std.string(error));
			}
		});
		addChild(button);
	}

	override public function dispose():Void {
		super.dispose();
		if (assets != null)
			assets.clean();
	}
}
