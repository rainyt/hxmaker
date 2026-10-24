package;

import hx.core.Hxmaker;
import hx.core.OpenFlBitmapData;
import hx.core.Render;
import hx.display.BitmapData;
import hx.display.Image;
import hx.display.Sprite;
import hx.display.Stage;
import hx.display.Graphics;
import hx.display.Label;
import hx.display.TextFormat;
import hx.display.BlendMode;
import hx.geom.ColorTransform;
import hx.geom.Rectangle;
import js.Browser;

/** 固定种子与模拟步长，所有模式使用相同显示对象及更新逻辑。 */
class GameStage extends Stage {
	private var images:Array<Image> = [];
	private var originsX:Array<Float> = [];
	private var originsY:Array<Float> = [];
	private var frame:Int = 0;
	private var config:Dynamic;
	private var seed:Int = 8731201;

	private function random():Float {
		seed = js.Syntax.code("(Math.imul({0}, 1664525) + 1013904223) | 0", seed);
		return (seed >>> 1) / 2147483648.;
	}
	private function parameter(name:String, fallback:String):String {
		var params:Dynamic = js.Syntax.code("new URLSearchParams(window.location.search)");
		var value:String = params.get(name);
		return value == null ? fallback : value;
	}
	private function number(name:String, fallback:Int, minimum:Int, maximum:Int):Int {
		var value = Std.parseInt(parameter(name, Std.string(fallback)));
		return value == null ? fallback : Std.int(Math.max(minimum, Math.min(maximum, value)));
	}

	override public function onStageInit():Void {
		super.onStageInit();
		config = {mode:#if benchmark_graphics_baseline "graphics" #else "direct" #end, count:number("count", 10000, 1, 100000), textures:number("textures", 1, 1, 32),
			scenario:parameter("scenario", "moving"), warmup:number("warmup", 5000, 0, 60000), duration:number("duration", 15000, 100, 120000),
			diagnostic:parameter("diagnostic", "0") == "1", seed:seed, width:960, height:640, dpr:Browser.window.devicePixelRatio};
		if (config.scenario == "cache") cast(Hxmaker.engine.renderer, Render).cacheAsBitmap = true;
		var textures:Array<BitmapData> = [];
		for (i in 0...config.textures) {
			var color = [0xff73c9f4, 0xfff4b773, 0xffae8df0, 0xff7fe0a6, 0xfff483ac, 0xffe5e57b][i % 6];
			var bitmap = new openfl.display.BitmapData(16, 16, true, color);
			bitmap.fillRect(new openfl.geom.Rectangle(0, 0, 8, 8), 0x88777777 | (color & 0x00ffffff));
			textures.push(BitmapData.formData(new OpenFlBitmapData(bitmap)));
		}
		for (i in 0...config.count) {
			var image = new Image(textures[i % textures.length]);
			var x = random() * 940, y = random() * 620;
			image.x = x; image.y = y;
			if (config.scenario != "overlap" && config.scenario != "correctness" && config.scenario != "cache") image.scaleX = image.scaleY = 0.25;
			if (config.scenario == "overlap") { image.x = x * 0.2 + 350; image.y = y * 0.2 + 220; }
			if (config.scenario == "correctness" || config.scenario == "cache") {
				image.rotation = i * 17 % 360; image.alpha = 0.2 + i % 5 * 0.16;
				image.scaleX = i % 3 == 0 ? -1.8 : 1.8; image.scaleY = 1.3;
				if (i % 3 == 0) image.blendMode = ADD;
				if (i % 7 == 0) image.smoothing = false;
			}
			addChild(image); images.push(image); originsX.push(image.x); originsY.push(image.y);
		}
		if (config.scenario == "correctness" || config.scenario == "cache") addCompatibilityFixture(textures[0]);
		BenchmarkProbe.install(cast Hxmaker.engine.renderer, config);
	}

	private function addCompatibilityFixture(texture:BitmapData):Void {
		var clipped = new Sprite(); clipped.x = 60; clipped.y = 80; clipped.maskRect = new Rectangle(0, 0, 60, 40); addChild(clipped);
		for (i in 0...8) { var image = new Image(texture); image.x = i * 12; image.scaleX = image.scaleY = 3; clipped.addChild(image); }
		var tinted = new Image(texture); tinted.x = 160; tinted.y = 80; tinted.scaleX = tinted.scaleY = 4;
		tinted.colorTransform = new ColorTransform(0.4, 0.8, 1, 0.7, 20, 0, 0, 0); addChild(tinted);
		var graphic = new Graphics(); graphic.beginFill(0xef8e66); graphic.drawCircle(320, 100, 40, 0.6); addChild(graphic);
		var tail = new Image(texture); tail.x = 300; tail.y = 110; tail.scaleX = tail.scaleY = 4; addChild(tail);
		var custom = new Image(texture); custom.x = 400; custom.y = 80; custom.scaleX = custom.scaleY = 4;
		custom.shader = new hx.shader.GeryShader(); addChild(custom);
		var blurred = new Image(texture); blurred.x = 500; blurred.y = 80; blurred.scaleX = blurred.scaleY = 4;
		blurred.filters = [new hx.filters.BlurFilter(2, 2)]; addChild(blurred);
		var source = new Sprite();
		var sourceImage = new Image(texture); sourceImage.x = 12; sourceImage.y = 12; sourceImage.scaleX = sourceImage.scaleY = 3; source.addChild(sourceImage);
		var offscreen = OpenFlBitmapData.fromSize(80, 80, true, 0);
		offscreen.draw(source);
		var result = new Image(offscreen); result.x = 600; result.y = 80; addChild(result);
		var label = new Label(); label.x = 24; label.y = 570; label.width = 850; label.height = 40;
		label.textFormat = new TextFormat(null, 24, 0xffffff); label.data = "OpenGL 直接渲染 / Abc 123"; addChild(label);
		var modes:Array<BlendMode> = [NORMAL, ADD, SCREEN, MULTIPLY, DIFFERENCE, SUBTRACT, SUBTRACT_FAST, INVERT, DARKEN, LIGHTEN, LAYER, HARDLIGHT, OVERLAY];
		for (i in 0...modes.length) {
			var base = new Image(texture); base.x = 30 + i % 7 * 125; base.y = 370 + Std.int(i / 7) * 90;
			base.scaleX = base.scaleY = 3; addChild(base);
			var blend = new Image(texture); blend.x = base.x + 20; blend.y = base.y + 20; blend.scaleX = blend.scaleY = 3;
			blend.alpha = 0.6;
			if (modes[i] == LAYER) {
				var group = new Sprite(); group.blendMode = LAYER; group.addChild(blend); addChild(group);
				var alpha = new Image(texture); alpha.x = blend.x + 8; alpha.y = blend.y; alpha.scaleX = alpha.scaleY = 3; alpha.blendMode = ALPHA; group.addChild(alpha);
				var erase = new Image(texture); erase.x = blend.x + 30; erase.y = blend.y + 20; erase.blendMode = ERASE; group.addChild(erase);
			} else { blend.blendMode = modes[i]; addChild(blend); }
		}
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (BenchmarkProbe.state == null || BenchmarkProbe.state.done) return;
		var start = Browser.window.performance.now();
		frame++;
		var moving = config.scenario == "moving" || config.scenario == "partial" || config.scenario == "overlap";
		if (moving) {
			var offset = frame % 960;
			for (i in 0...images.length) {
				if (config.scenario == "partial" && i % 10 != 0) continue;
				images[i].x = (originsX[i] + offset * (1 + i % 3) * 0.25) % 940;
			}
		} else if (config.scenario == "rebuild") {
			// 显式要求重建，和自然静止场景区分开。
			invalidate();
		}
		BenchmarkProbe.state.updateMs = Browser.window.performance.now() - start;
	}
}
