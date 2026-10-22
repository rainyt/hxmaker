package;

import hx.display.Graphics;
import hx.display.Stage;
import hx.display.graphics.GraphicsPath;
import hx.display.graphics.GraphicsStrokeStyle;
import hx.geom.ColorTransform;
import hx.geom.Point;

/** 无测试框架依赖的回归示例，只在按钮点击或 graphics_checks 编译开关下运行。 */
@:access(hx.display.Graphics)
@:access(hx.display.DisplayObject)
@:access(hx.display.DisplayObjectContainer)
class GraphicsChecks {
	public static function run():Array<String> {
		var cases:Array<{name:String, check:Void->Void}> = [
			{name: "多次绘制的整体边界", check: boundsUnion},
			{name: "未引用顶点不扩大边界", check: unusedVertices},
			{name: "绘图与清空通知舞台刷新", check: dirtyNotification},
			{name: "清空重置画笔和线宽", check: clearState},
			{name: "填充与描边颜色独立", check: independentStyles},
			{name: "折线和圆描边保留参数", check: legacyParameters},
			{name: "凹多边形双向三角化", check: concaveFill},
			{name: "二次、三次曲线及圆弧", check: curvesAndArc},
			{name: "连续转角没有重复补片", check: strokeArea},
			{name: "端点范围与斜接限制", check: strokeStyles},
			{name: "路径修改不污染已提交图形", check: pathSnapshot},
			{name: "样式修改不污染已提交描边", check: styleSnapshot},
			{name: "空集、重复点和零半径安全", check: degenerateInputs},
			{name: "非法输入明确报错", check: invalidInputs},
			{name: "自交、孔洞拒绝且提交原子化", check: unsupportedContours},
			{name: "低层引用修改可手动失效", check: borrowedGeometry}
		];
		var report:Array<String> = [];
		var passed = 0;
		for (entry in cases) {
			try {
				entry.check();
				report.push("通过：" + entry.name);
				passed++;
			} catch (error:Dynamic) {
				report.push("失败：" + entry.name + "；" + Std.string(error));
			}
		}
		report.unshift("通过 " + passed + " / " + cases.length + " 项");
		return report;
	}

	private static function boundsUnion():Void {
		var g = new Graphics();
		g.beginFill(0xffffff);
		g.drawRect(-20, -10, 10, 10);
		g.drawRect(30, 40, 20, 30);
		var bounds = g.getBounds(g);
		near(bounds.x, -20); near(bounds.y, -10);
		near(bounds.width, 70); near(bounds.height, 80);
	}

	private static function unusedVertices():Void {
		var g = new Graphics();
		g.drawTriangles([0, 0, 10, 0, 0, 10, 999, 999], [0, 1, 2], [0, 0, 1, 0, 0, 1, 1, 1]);
		near(g.getBounds(g).width, 10);
		near(g.getBounds(g).height, 10);
	}

	private static function dirtyNotification():Void {
		var stage = new Stage();
		var g = new Graphics();
		stage.addChild(g);
		stage.__dirty = false;
		stage.__layoutDirty = false;
		g.drawRect(0, 0, 10, 10);
		ensure(stage.__dirty, "绘图后舞台没有标脏");
		ensure(stage.__layoutDirty, "图形尺寸变化没有通知父容器布局");
		stage.__dirty = false;
		g.clear();
		ensure(stage.__dirty, "清空后舞台没有标脏");
		near(g.getBounds(g).width, 0);
		stage.dispose();
	}

	private static function clearState():Void {
		var g = new Graphics();
		g.beginLineStyle(0xff0000, 12);
		g.moveTo(100, 100); g.lineTo(200, 100);
		g.clear();
		g.lineTo(10, 0);
		var bounds = g.getBounds(g);
		near(bounds.x, 0); near(bounds.width, 10);
		near(bounds.y, -0.5); near(bounds.height, 1);
		var mesh = records(g)[0];
		near(mesh.color.redMultiplier, 0);
		near(mesh.color.greenMultiplier, 0);
		near(mesh.color.blueMultiplier, 0);
	}

	private static function independentStyles():Void {
		var g = new Graphics();
		g.beginLineStyle(0xff0000, 4);
		g.beginFill(0x0000ff);
		g.drawRect(0, 0, 10, 10);
		g.drawLine(0, 20, 10, 20);
		var path = new GraphicsPath().moveTo(0, 0).lineTo(10, 0).lineTo(0, 10).closePath();
		g.fillPath(path, 0x00ff00);
		g.drawRect(20, 0, 10, 10);
		var data = records(g);
		near(data[0].color.blueMultiplier, 1);
		near(data[1].color.redMultiplier, 1);
		near(data[1].color.blueMultiplier, 0);
		near(data[2].color.greenMultiplier, 1);
		near(data[3].color.blueMultiplier, 1);
	}

	private static function legacyParameters():Void {
		var g = new Graphics();
		var color = new ColorTransform(0.2, 0.4, 0.6, 0.8);
		g.beginLineStyle(0xffffff, 3);
		g.drawLines([new Point(), new Point(20, 0), new Point(20, 20)], 0.3, color, false);
		g.drawCircleLine(60, 60, 20, 4, 0.45, color);
		var data = records(g);
		ensure(data.length == 2, "折线和圆描边应该各提交一份网格");
		near(data[0].alpha, 0.3); near(data[1].alpha, 0.45);
		for (mesh in data) {
			near(mesh.color.redMultiplier, 0.2);
			near(mesh.color.alphaMultiplier, 0.8);
		}
	}

	private static function concaveFill():Void {
		var points = [new Point(0, 0), new Point(80, 0), new Point(80, 30), new Point(30, 30), new Point(30, 80), new Point(0, 80)];
		for (_ in 0...2) {
			var path = new GraphicsPath();
			for (i in 0...points.length) {
				var p = points[i];
				if (i == 0) path.moveTo(p.x, p.y); else path.lineTo(p.x, p.y);
			}
			path.closePath();
			var g = new Graphics();
			g.fillPath(path);
			var mesh = records(g)[0];
			near(area(mesh), 3900);
			for (i in 0...Std.int(mesh.indices.length / 3)) {
				var x = 0., y = 0.;
				for (j in 0...3) {
					var index = mesh.indices[i * 3 + j] * 2;
					x += mesh.vertices[index] / 3;
					y += mesh.vertices[index + 1] / 3;
				}
				ensure(x <= 30 || y <= 30, "三角形错误填充了凹槽");
			}
			points.reverse();
		}
		// 不同轮廓各自归一化，远处的小轮廓也必须保留。
		var separated = new GraphicsPath().moveTo(0, 0).lineTo(10, 0).lineTo(0, 10).closePath();
		separated.moveTo(1e9, 1e9).lineTo(1e9 + 10, 1e9).lineTo(1e9, 1e9 + 10).closePath();
		var g = new Graphics();
		g.fillPath(separated);
		near(area(records(g)[0]), 100);
	}

	private static function curvesAndArc():Void {
		var path = new GraphicsPath().moveTo(0, 0);
		path.quadraticCurveTo(50, -100, 100, 0).bezierCurveTo(130, 100, 170, -100, 200, 0);
		var g = new Graphics();
		g.strokePath(path, 0xffffff, 2);
		ensure(g.getBounds(g).y < -40, "二次曲线没有细分出弯曲轮廓");
		ensure(g.getBounds(g).height > 70, "三次曲线没有细分出弯曲轮廓");
		g.clear();
		g.fillPath(new GraphicsPath().arc(0, 0, 30, 0, Math.PI * 2).closePath(), 0xffffff, 1, 0.01);
		near(area(records(g)[0]), Math.PI * 900, 2);
		g.clear();
		// 起终点相同、控制点共线但超出端点时，不能把整段曲线当作零长度直线。
		g.strokePath(new GraphicsPath().moveTo(0, 0).bezierCurveTo(100, 0, -100, 0, 0, 0));
		ensure(g.getBounds(g).width > 50, "共线折返曲线被错误丢弃");
	}

	private static function strokeArea():Void {
		var path = new GraphicsPath().moveTo(0, 0).lineTo(100, 0).lineTo(100, 100);
		var g = new Graphics();
		g.strokePath(path, 0xffffff, 20, 0.5, new GraphicsStrokeStyle(BUTT, BEVEL));
		near(area(records(g)[0]), 3950);
		// 同一路径通过旧接口提交，也应采用共享转角截面。
		g.clear(); g.beginLineStyle(0xffffff, 20);
		g.moveTo(0, 0); g.lineTo(100, 0, true, 0.5); g.lineTo(100, 100, true, 0.5);
		ensure(records(g).length == 1, "连续折线没有合并为单份网格");
		near(area(records(g)[0]), 3950);
		// 第三个转角只应调整前一段的末端，不能破坏已经生成的起点连接。
		g.lineTo(200, 100, true, 0.5);
		near(area(records(g)[0]), 5900);
	}

	private static function strokeStyles():Void {
		var line = new GraphicsPath().moveTo(0, 0).lineTo(100, 0);
		var g = new Graphics();
		g.strokePath(line, 0xffffff, 20, 1, new GraphicsStrokeStyle(SQUARE));
		var bounds = g.getBounds(g);
		near(bounds.x, -10); near(bounds.width, 120);
		g.clear();
		g.strokePath(line, 0xffffff, 20, 1, new GraphicsStrokeStyle(ROUND), 0.01);
		near(area(records(g)[0]), 2000 + Math.PI * 100, 1);
		g.clear();
		var corner = new GraphicsPath().moveTo(0, 0).lineTo(100, 0).lineTo(100, 100);
		g.strokePath(corner, 0xffffff, 20, 1, new GraphicsStrokeStyle(BUTT, MITER, 1));
		near(area(records(g)[0]), 3950);
		g.clear();
		g.strokePath(corner, 0xffffff, 20, 1, new GraphicsStrokeStyle(BUTT, MITER, 4));
		near(area(records(g)[0]), 4000);
	}

	private static function pathSnapshot():Void {
		var path = new GraphicsPath().moveTo(0, 0).lineTo(10, 0).lineTo(0, 10).closePath();
		var original = new Graphics();
		original.fillPath(path);
		var before = records(original)[0].vertices.copy();
		path.clear().moveTo(100, 100).lineTo(200, 100).lineTo(100, 200).closePath();
		var next = new Graphics(); next.fillPath(path);
		near(original.getBounds(original).width, 10);
		near(next.getBounds(next).width, 100);
		ensure(records(original)[0].vertices.join(",") == before.join(","), "路径变化污染了旧网格");
	}

	private static function styleSnapshot():Void {
		var path = new GraphicsPath().moveTo(0, 0).lineTo(100, 0);
		var style = new GraphicsStrokeStyle(BUTT);
		var first = new Graphics(); first.strokePath(path, 0xffffff, 20, 1, style);
		style.cap = SQUARE;
		var second = new Graphics(); second.strokePath(path, 0xffffff, 20, 1, style);
		near(first.getBounds(first).width, 100);
		near(second.getBounds(second).width, 120);
	}

	private static function degenerateInputs():Void {
		var g = new Graphics();
		g.drawLines([]); g.drawLines([new Point()]);
		g.drawLine(1, 1, 1, 1);
		g.drawCircle(0, 0, 0); g.drawCircleLine(0, 0, 0);
		g.fillPath(new GraphicsPath()); g.strokePath(new GraphicsPath());
		ensure(records(g).length == 0, "退化输入产生了无效网格");
		var path = new GraphicsPath().moveTo(0, 0).lineTo(0, 0).lineTo(30, 0).lineTo(30, 30).lineTo(0, 30).lineTo(0, 0).closePath();
		g.fillPath(path);
		near(area(records(g)[0]), 900);
	}

	private static function invalidInputs():Void {
		var g = new Graphics();
		reject(() -> g.drawTriangles([0, 0, 10, 0, 0, 10], [0, 1, 9], [0, 0, 1, 0, 0, 1]));
		reject(() -> g.drawTriangles([0, 0, 10], [0, 1, 2], [0, 0, 1, 0]));
		reject(() -> g.drawTriangles([0, 0, 10, 0, 0, 10], [0, 1], [0, 0, 1, 0, 0, 1]));
		reject(() -> g.drawRectMask(0, 0, 10, 10, 0, 32));
		reject(() -> g.drawCircle(0, 0, -1));
		reject(() -> g.drawCircle(0, 0, 10, 0));
		reject(() -> g.moveTo(Math.NaN, 0));
		reject(() -> g.strokePath(new GraphicsPath(), 0, -1));
		reject(() -> g.fillPath(new GraphicsPath(), 0, 1, 0));
		reject(() -> g.strokePath(new GraphicsPath(), 0, 1, 1, new GraphicsStrokeStyle(BUTT, MITER, 0)));
		reject(() -> { new GraphicsPath().bezierCurveTo(1, 1, 2, 2, 3, 3); });
		ensure(records(g).length == 0, "非法输入部分提交了网格");
	}

	private static function unsupportedContours():Void {
		var g = new Graphics();
		g.drawRect(0, 0, 10, 10);
		var count = g.__graphicsDrawData.draws.length;
		var bow = new GraphicsPath().moveTo(0, 0).lineTo(30, 30).lineTo(0, 30).lineTo(30, 0).closePath();
		reject(() -> g.fillPath(bow));
		var hole = new GraphicsPath().moveTo(0, 0).lineTo(100, 0).lineTo(100, 100).lineTo(0, 100).closePath();
		hole.moveTo(20, 20).lineTo(80, 20).lineTo(80, 80).lineTo(20, 80).closePath();
		reject(() -> g.fillPath(hole));
		ensure(g.__graphicsDrawData.draws.length == count, "失败的填充留下了部分命令");
	}

	private static function borrowedGeometry():Void {
		var g = new Graphics();
		var vertices:Array<Float> = [0, 0, 10, 0, 0, 10];
		g.drawTriangles(vertices, [0, 1, 2], [0, 0, 1, 0, 0, 1]);
		near(g.getBounds(g).width, 10);
		vertices[2] = 40;
		g.invalidate();
		near(g.getBounds(g).width, 40);
	}

	private static function records(g:Graphics):Array<MeshRecord> {
		var result:Array<MeshRecord> = [];
		for (draw in g.__graphicsDrawData.draws) switch draw {
			case DRAW_TRIANGLE(vertices, indices, _, alpha, color, _):
				result.push({vertices: vertices, indices: indices, alpha: alpha, color: color});
			default:
		}
		return result;
	}

	private static function area(mesh:MeshRecord):Float {
		var result = 0.;
		for (i in 0...Std.int(mesh.indices.length / 3)) {
			var a = mesh.indices[i * 3] * 2, b = mesh.indices[i * 3 + 1] * 2, c = mesh.indices[i * 3 + 2] * 2;
			result += Math.abs((mesh.vertices[b] - mesh.vertices[a]) * (mesh.vertices[c + 1] - mesh.vertices[a + 1])
				- (mesh.vertices[b + 1] - mesh.vertices[a + 1]) * (mesh.vertices[c] - mesh.vertices[a])) * 0.5;
		}
		return result;
	}

	private static function reject(action:Void->Void):Void {
		var thrown = false;
		try action() catch (_:Dynamic) thrown = true;
		ensure(thrown, "预期抛出明确错误，但调用成功了");
	}

	private static function near(actual:Float, expected:Float, tolerance:Float = 1e-6):Void {
		ensure(Math.isFinite(actual) && Math.abs(actual - expected) <= tolerance, "预期 " + expected + "，实际 " + actual);
	}

	private static function ensure(condition:Bool, message:String):Void {
		if (!condition) throw message;
	}
}

private typedef MeshRecord = {
	var vertices:Array<Float>;
	var indices:Array<Int>;
	var alpha:Float;
	var color:ColorTransform;
}
