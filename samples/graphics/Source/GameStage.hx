package;

import hx.display.Box;
import hx.display.Graphics;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Stage;
import hx.display.TextFormat;
import hx.display.graphics.GraphicsLineCap;
import hx.display.graphics.GraphicsLineJoin;
import hx.display.graphics.GraphicsPath;
import hx.display.graphics.GraphicsStrokeStyle;
import hx.events.MouseEvent;
import hx.geom.ColorTransform;
import hx.geom.Point;

/** 自由图形展示、手绘区域和手动回归检查。 */
class GameStage extends Stage {
	private var status:Label;
	private var results:Label;
	private var drawing:Bool = false;
	private var ink:Graphics;
	private var inkPath:GraphicsPath;
	private var inkPoints:Int = 0;
	private var lastInkX:Float = 0;
	private var lastInkY:Float = 0;
	private var strokes:Array<GraphicsPath> = [];
	private var redraw:Graphics;
	private var redrawCount:Int = 0;

	override public function onStageInit():Void {
		super.onStageInit();
		text("Graphics 路径绘图", 24, 16, 26);
		text("曲线 / 凹多边形 / 描边 / 半透明 / 手绘 / 状态回归", 24, 53, 15, 0xa8b8d5);
		showShapes();
		showStrokes();
		showLegacy();
		showInk();
		status = text("点击右侧按钮运行检查；在左下区域拖动绘制。", 24, 744, 14, 0xa8b8d5);
		action("清空手绘", 24, 776, clearInk);
		action("静止画面重绘", 180, 776, redrawShape);
		action("运行回归检查", 336, 776, () -> {
			var report = GraphicsChecks.run();
			results.data = report.join("\n");
			status.data = "回归检查已完成，详细结果显示在右下区域及控制台。";
			for (line in report) trace(line);
		});
		#if graphics_checks
		var report = GraphicsChecks.run();
		results.data = report.join("\n");
		for (line in report) trace(line);
		#end
	}

	private function showShapes():Void {
		panel("曲线轮廓与凹多边形填充", 24, 92, 520, 210);
		var graphics = new Graphics();
		graphics.x = 46; graphics.y = 137;
		addChild(graphics);
		var heart = new GraphicsPath().moveTo(65, 28);
		heart.bezierCurveTo(15, -25, -30, 45, 65, 120);
		heart.bezierCurveTo(160, 45, 115, -25, 65, 28).closePath();
		graphics.fillPath(heart, 0xf16f8d, 0.8);
		graphics.strokePath(heart, 0xffc4d0, 3, 1, new GraphicsStrokeStyle(ROUND, ROUND));
		var star = new GraphicsPath();
		for (i in 0...10) {
			var a = -Math.PI / 2 + i * Math.PI / 5;
			var r = i % 2 == 0 ? 66. : 28.;
			var x = 245 + Math.cos(a) * r, y = 64 + Math.sin(a) * r;
			if (i == 0) star.moveTo(x, y); else star.lineTo(x, y);
		}
		star.closePath();
		graphics.fillPath(star, 0xffcf70);
		graphics.strokePath(star, 0xffedbd, 3, 1, new GraphicsStrokeStyle(BUTT, MITER, 3));
		var sector = new GraphicsPath().moveTo(420, 64).arc(420, 64, 62, -Math.PI * 0.8, Math.PI * 0.55).closePath();
		graphics.fillPath(sector, 0x5dc5d8, 0.75);
		graphics.strokePath(sector, 0xc3f4ff, 3);
	}

	private function showStrokes():Void {
		panel("端点 / 转角 / 斜接限制", 566, 92, 530, 210);
		var caps:Array<GraphicsLineCap> = [BUTT, SQUARE, ROUND];
		var joins:Array<GraphicsLineJoin> = [MITER, BEVEL, ROUND];
		for (i in 0...3) {
			var x = 590 + i * 167;
			text(Std.string(caps[i]) + " / " + Std.string(joins[i]), x, 133, 13);
			var graphics = new Graphics();
			addChild(graphics);
			var path = new GraphicsPath().moveTo(x + 10, 236).lineTo(x + 62, 177).lineTo(x + 114, 236);
			graphics.strokePath(path, 0x8faaff, 18, 0.55, new GraphicsStrokeStyle(caps[i], joins[i], 2));
			// 半透明转角应保持连贯，不出现重复叠加形成的深色补片。
			graphics.beginLineStyle(0xe4ebff, 1);
			graphics.drawLine(x + 10, 236, x + 114, 236);
		}
		text("miterLimit=2，过尖的斜接自动退化为削角。", 590, 270, 13, 0xa8b8d5);
	}

	private function showLegacy():Void {
		panel("旧接口参数传递与独立描边颜色", 24, 320, 520, 130);
		var graphics = new Graphics();
		addChild(graphics);
		graphics.beginLineStyle(0xffcd70, 8);
		graphics.beginFill(0x5988f0);
		graphics.drawRect(48, 371, 78, 52, 0.5);
		graphics.drawCircleLine(195, 398, 29, 5, 0.4);
		graphics.drawLines([new Point(260, 420), new Point(305, 372), new Point(350, 420)], 0.4, null, false);
		graphics.drawCircleLine(424, 398, 29, 5, 0.6, new ColorTransform(0.4, 1, 0.7));
		redraw = new Graphics();
		addChild(redraw);
	}

	private function showInk():Void {
		panel("自由手绘：按住并拖动", 24, 470, 520, 252);
		var area = new Box();
		area.x = 36; area.y = 510; area.width = 496; area.height = 200;
		area.background = new Quad(496, 200, 0x111725);
		area.mouseClickEnabled = true;
		addChild(area);
		ink = new Graphics();
		ink.x = 36; ink.y = 510;
		ink.mouseEnabled = false;
		addChild(ink);
		area.addEventListener(MouseEvent.MOUSE_DOWN, (e:MouseEvent) -> {
			drawing = true;
			lastInkX = e.stageX - 36; lastInkY = e.stageY - 510;
			inkPath = new GraphicsPath().moveTo(lastInkX, lastInkY);
			inkPoints = 1;
			strokes.push(inkPath);
		});
		addEventListener(MouseEvent.MOUSE_MOVE, (e:MouseEvent) -> {
			if (!drawing) return;
			if (e.stageX < 36 || e.stageX > 532 || e.stageY < 510 || e.stageY > 710) {
				drawing = false;
				return;
			}
			var x = e.stageX - 36, y = e.stageY - 510;
			var dx = x - lastInkX, dy = y - lastInkY;
			if (dx * dx + dy * dy < 4) return;
			// 示例主动拆分长笔画，避免无限采样触及路径复杂度限制。
			if (inkPoints >= 1024) {
				inkPath = new GraphicsPath().moveTo(lastInkX, lastInkY);
				strokes.push(inkPath);
				inkPoints = 1;
			}
			inkPath.lineTo(x, y);
			inkPoints++;
			lastInkX = x; lastInkY = y;
			refreshInk();
		});
		addEventListener(MouseEvent.MOUSE_UP, (_:MouseEvent) -> drawing = false);
		panel("手动回归检查结果", 566, 320, 530, 402);
		results = text("尚未运行。点击下方“运行回归检查”。", 586, 362, 13, 0xa8b8d5);
		results.width = 492; results.height = 348; results.wordWrap = true;
	}

	private function refreshInk():Void {
		ink.clear();
		for (path in strokes) ink.strokePath(path, 0x7fdbce, 5, 0.8, new GraphicsStrokeStyle(ROUND, ROUND));
	}

	private function clearInk():Void {
		drawing = false;
		strokes = [];
		ink.clear();
		status.data = "手绘已清空。";
	}

	private function redrawShape():Void {
		// 这里只修改 Graphics，不移动对象、不更新文字，用于观察脏标记是否主动触发刷新。
		redraw.clear();
		redraw.beginFill(redrawCount++ % 2 == 0 ? 0xe879a7 : 0x74d9b7);
		redraw.drawRect(492, 374, 22, 44);
	}

	private function panel(title:String, x:Float, y:Float, width:Float, height:Float):Void {
		var background = new Quad(width, height, 0x222c40);
		background.x = x; background.y = y;
		addChild(background);
		text(title, x + 16, y + 12, 16);
	}

	private function text(value:String, x:Float, y:Float, size:Int, color:Int = 0xe1e9fa):Label {
		var label = new Label(value, new TextFormat(null, size, color));
		label.x = x; label.y = y;
		label.mouseEnabled = false;
		addChild(label);
		return label;
	}

	private function action(title:String, x:Float, y:Float, callback:Void->Void):Void {
		var button = new Box();
		button.x = x; button.y = y; button.width = 144; button.height = 32;
		button.background = new Quad(144, 32, 0x365080);
		button.mouseClickEnabled = true;
		button.mouseChildren = false;
		var label = new Label(title, new TextFormat(null, 14, 0xffffff));
		label.x = 12; label.y = 5;
		button.addChild(label);
		button.addEventListener(MouseEvent.CLICK, (_:MouseEvent) -> callback());
		addChild(button);
	}
}
