package;

import haxe.Timer;
import hx.display.Box;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Stage;
import hx.display.TextFormat;
import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Point;
import hx.ui.UIAnimate;
import hx.ui.UIAnimateGroup;
import hx.ui.UIAssets;
import motion.Actuate;

/** 使用真实 XML 动画展示时间定位；由用户操作和判断结果，不自动执行验收。 */
class GameStage extends Stage {
	private static inline var TRACK_WIDTH:Float = 780;
	private var timeline:UIAnimateGroup;
	private var singleMove:UIAnimate;
	private var single:Quad;
	private var delayed:Quad;
	private var sequence:Quad;
	private var implicit:Quad;
	private var instant:Quad;
	private var defaultEase:Quad;
	private var scrubber:Box;
	private var scrubFill:Quad;
	private var scrubHead:Quad;
	private var status:Label;
	private var values:Label;
	private var currentTime:Float = 0;
	private var previousStamp:Float = 0;
	private var direction:Float = 1;
	private var playing:Bool = false;
	private var dragging:Bool = false;
	private var nativePlaying:Bool = false;
	private var nativeGroupPlaying:Bool = false;
	private var nativeStartTime:Float = 0;

	override public function onStageInit():Void {
		super.onStageInit();
		addText("UIAnimate / 动画组：seek 时间定位", 24, 18, 1052, 36, 26, 0xffffff);
		addText("拖动下方时间轴，观察六种动画。定位单位为秒，动画组总时长为 2.5 秒。", 24, 60, 1052, 26);
		var titles:Array<String> = ["线性位移 + 透明度", "延迟 1 秒 + 缓动旋转", "同属性两段 + 间隔", "省略结束值，捕获基准", "延迟 1 秒后瞬间跳转", "默认缓动（未指定 ease）"];
		for (index in 0...titles.length) {
			var y:Float = 122 + index * 64;
			addQuad(220, y + 15, 760, 2, 0x34435a);
			addText(titles[index], 24, y, 192, 34, 15);
		}
		var ids:Map<String, Dynamic> = [];
		var assets:UIAssets = new UIAssets("");
		var content:String = openfl.Assets.getText("assets/views/SeekDemo.xml");
		assets.buildItem(Xml.parse(content).firstElement(), this, ids);
		timeline = cast ids.get("timeline");
		// 组内动画按现有构建规则不单独注册 ID，直接取得第一段。
		singleMove = timeline.animates[0];
		single = cast ids.get("single");
		delayed = cast ids.get("delayed");
		sequence = cast ids.get("sequence");
		implicit = cast ids.get("implicit");
		instant = cast ids.get("instant");
		defaultEase = cast ids.get("defaultEase");
		updateLayout();
		timeline.updateOption();

		// 首行的独立缩放补间用于观察 seek 不会停止同目标上的其他补间。
		Actuate.tween(single, 0.8, {scaleY: 1.5}, false).repeat().reflect();
		addText("首行持续上下伸缩：这是独立 Actuate 补间，seek 后也应继续。", 24, 520, 1052, 28, 15, 0x79dfbe);
		addAction("正向预览", 24, 565, 136, () -> startPreview(1));
		addAction("反向预览", 172, 565, 136, () -> startPreview(-1));
		addAction("暂停", 320, 565, 108, () -> locate(currentTime));
		addAction("重置到开头", 440, 565, 144, () -> locate(0));
		addAction("原生播放首行", 596, 565, 160, () -> {
			locate(0);
			singleMove.play(true);
			nativePlaying = true;
			refreshStatus();
		});
		addAction("定位到末尾", 768, 565, 144, () -> locate(timeline.totalDuration));
		addAction("原生播放整组", 924, 565, 152, () -> {
			locate(0);
			timeline.play(true);
			nativePlaying = nativeGroupPlaying = true;
			nativeStartTime = Timer.stamp();
			refreshStatus();
		});
		addText("0 秒", 24, 627, 170, 28);
		buildScrubber();
		addText("2.5 秒", 1014, 627, 72, 28);
		status = addText("", 24, 677, 1052, 28, 17, 0x79dfbe);
		values = addText("", 24, 710, 1052, 28, 14);
		var times:Array<Float> = [-1, 0, 0.5, 1, 1.5, 2, 2.5, 4];
		for (index in 0...times.length) {
			var time:Float = times[index];
			addAction(Std.string(time) + " 秒", 24 + index * 132, 756, 120, () -> locate(time));
		}
		addText("负时间保持开头，超出总时长保持末尾；反复前后定位不应改变绿色方块的结束值。", 24, 807, 1052, 24, 14);
		addEventListener(MouseEvent.MOUSE_MOVE, onPointerMove);
		addEventListener(MouseEvent.MOUSE_UP, onPointerUp);
		addEventListener(Event.DEACTIVATE, handlePreviewDeactivate);
		addEventListener(Event.UPDATE, handlePreviewUpdate);
		previousStamp = Timer.stamp();
		locate(0);
	}

	private function buildScrubber():Void {
		scrubber = new Box();
		scrubber.x = 220;
		scrubber.y = 624;
		scrubber.width = TRACK_WIDTH;
		scrubber.height = 34;
		scrubber.mouseChildren = false;
		scrubber.background = new Quad(TRACK_WIDTH, 34, 0x222e40);
		scrubFill = new Quad(1, 8, 0x467bc1);
		scrubFill.y = 13;
		scrubber.addChild(scrubFill);
		scrubHead = new Quad(8, 30, 0xbad9ff);
		scrubHead.y = 2;
		scrubber.addChild(scrubHead);
		scrubber.addEventListener(MouseEvent.MOUSE_DOWN, (event:MouseEvent) -> {
			dragging = true;
			seekFromPointer(event);
		});
		addChild(scrubber);
	}

	private function seekFromPointer(event:MouseEvent):Void {
		var point:Point = scrubber.globalToLocal(new Point(event.stageX, event.stageY));
		var ratio:Float = Math.max(0, Math.min(1, point.x / TRACK_WIDTH));
		locate(ratio * timeline.totalDuration);
	}

	private function onPointerMove(event:MouseEvent):Void {
		if (dragging)
			seekFromPointer(event);
	}

	private function onPointerUp(event:MouseEvent):Void {
		if (dragging)
			seekFromPointer(event);
		dragging = false;
	}

	private function handlePreviewDeactivate(event:Event):Void {
		dragging = false;
		locate(currentTime);
	}

	private function locate(time:Float):Void {
		playing = false;
		nativePlaying = false;
		nativeGroupPlaying = false;
		timeline.seek(time);
		currentTime = Math.max(0, Math.min(timeline.totalDuration, time));
		refreshStatus();
	}

	private function startPreview(nextDirection:Float):Void {
		direction = nextDirection;
		if (direction > 0 && currentTime >= timeline.totalDuration)
			currentTime = 0;
		if (direction < 0 && currentTime <= 0)
			currentTime = timeline.totalDuration;
		locate(currentTime);
		playing = true;
		previousStamp = Timer.stamp();
		refreshStatus();
	}

	private function handlePreviewUpdate(event:Event):Void {
		var stamp:Float = Timer.stamp();
		var elapsed:Float = stamp - previousStamp;
		previousStamp = stamp;
		if (nativeGroupPlaying) {
			currentTime = Math.min(timeline.totalDuration, stamp - nativeStartTime);
			if (currentTime >= timeline.totalDuration) nativePlaying = nativeGroupPlaying = false;
		}
		if (playing) {
			currentTime = Math.max(0, Math.min(timeline.totalDuration, currentTime + elapsed * direction));
			timeline.seek(currentTime);
			if (direction > 0 && currentTime >= timeline.totalDuration || direction < 0 && currentTime <= 0)
				playing = false;
		}
		refreshStatus();
	}

	private function refreshStatus():Void {
		if (status == null)
			return;
		var ratio:Float = timeline.totalDuration == 0 ? 0 : currentTime / timeline.totalDuration;
		scrubFill.width = Math.max(1, ratio * TRACK_WIDTH);
		scrubHead.x = ratio * (TRACK_WIDTH - scrubHead.width);
		var mode:String = nativePlaying ? (nativeGroupPlaying ? "整组原生播放中，拖动时间轴可接管" : "首行原生播放中，拖动时间轴可接管") : playing ? direction > 0 ? "正向预览" : "反向预览" : "已定位并保持静止";
		status.data = mode + "  |  时间 " + format(currentTime) + " / " + format(timeline.totalDuration) + " 秒";
		values.data = "位置 x：蓝 " + format(single.x) + "，橙 " + format(delayed.x) + "，紫 " + format(sequence.x)
			+ "，绿 " + format(implicit.x) + "（透明度 " + format(implicit.alpha) + "），粉 " + format(instant.x) + "，黄 " + format(defaultEase.x);
	}

	private function format(value:Float):String {
		return Std.string(Math.round(value * 1000) / 1000);
	}

	private function addQuad(x:Float, y:Float, width:Float, height:Float, color:UInt):Quad {
		var quad:Quad = new Quad(width, height, color);
		quad.x = x;
		quad.y = y;
		quad.mouseEnabled = false;
		addChild(quad);
		return quad;
	}

	private function addText(text:String, x:Float, y:Float, width:Float, height:Float, size:Int = 16, color:UInt = 0xbcc9db):Label {
		var label:Label = new Label(text, new TextFormat(null, size, color));
		label.x = x;
		label.y = y;
		label.width = width;
		label.height = height;
		label.wordWrap = false;
		label.verticalAlign = MIDDLE;
		label.mouseEnabled = false;
		addChild(label);
		return label;
	}

	private function addAction(text:String, x:Float, y:Float, width:Float, action:Void->Void):Void {
		var button:Box = new Box();
		button.x = x;
		button.y = y;
		button.width = width;
		button.height = 36;
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		button.background = new Quad(width, 36, 0x34435a);
		var label:Label = new Label(text, new TextFormat(null, 15, 0xffffff));
		label.width = width;
		label.height = 36;
		label.wordWrap = false;
		label.horizontalAlign = CENTER;
		label.verticalAlign = MIDDLE;
		button.addChild(label);
		button.addEventListener(MouseEvent.CLICK, (event:MouseEvent) -> {
			event.bubbling = false;
			event.preventDefault();
			action();
		});
		addChild(button);
	}
}
