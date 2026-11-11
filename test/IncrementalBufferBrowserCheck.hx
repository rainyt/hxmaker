package;

import hx.core.Hxmaker;
import hx.core.HxmakerApplication;
import hx.core.OpenFlBitmapData;
import hx.core.Render;
import hx.display.Box;
import hx.display.Image;
import hx.display.Quad;
import hx.display.Graphics;
import hx.display.graphics.GraphicsPath;
import hx.display.Label;
import hx.geom.Rectangle;
import hx.geom.ColorTransform;
import hx.render.TextFieldRender;
import hx.render.BufferBuildStats;
import hx.filters.RenderFilter;
import js.Browser;
import lime.graphics.opengl.GL;

/** 在真实 OpenFL WebGL 提交后，逐像素比较左右两种构建模式。 */
@:access(hx.core.Hxmaker)
@:access(hx.display.DisplayObject)
class IncrementalBufferBrowserCheck extends HxmakerApplication {
	private var cached:Render;
	private var full:Render;
	private var sceneRoot:Box;
	private var images:Array<Image> = [];
	private var label:Label;
	private var nested:Box;
	private var backdrop:Quad;
	private var mesh:Graphics;
	private var frame:Int = 0;
	private var checked:Int = 0;
	private var colored:Int = 0;

	private static function main():Void {
		var app:openfl.display.Application = new openfl.display.Application();
		app.createWindow({width:384, height:192, resizable:false, element:Browser.document.body,
			context:{type:WEBGL, antialiasing:0, background:0x101010}});
		untyped Browser.window.bufferDebug = app;
		app.exec();
		var test:IncrementalBufferBrowserCheck = null;
		// 第一次窗口渲染建立当前 GL 上下文后再初始化引擎着色器。
		app.window.onRender.add(function(context:lime.graphics.RenderContext):Void {
			// Stage 可能取消 onRender 的后续监听，微任务在本次同步绘制后读取像素。
			untyped Browser.window.queueMicrotask(function():Void {
			try {
				if (test == null) {
					test = new IncrementalBufferBrowserCheck();
					openfl.Lib.current.stage.addChild(test);
				} else {
					test.checkFrame();
				}
			} catch (error:Dynamic) {
				untyped Browser.window.bufferResult = {error:Std.string(error)};
				throw error;
			}
			});
		}, false, 1000);
	}

	public function new() {
		super();
		Hxmaker.__engine = cast {dt:0.016, get_stageWidth:() -> 192., get_stageHeight:() -> 192., get_devicePixelRatio:() -> 1.};
		cached = new Render(); full = new Render(); full.incrementalBufferEnabled = false;
		full.stage.x = 192;
		addChild(cached.stage); addChild(full.stage);
		sceneRoot = new Box();
		nested = new Box(); sceneRoot.addChild(nested);
		for (i in 0...24) {
			var bitmap:openfl.display.BitmapData = new openfl.display.BitmapData(16, 16, true, 0xff000000 | (i * 83711 + 0x2080));
			bitmap.fillRect(new openfl.geom.Rectangle(4, 4, 8, 8), 0xffffcc00);
			var image:Image = new Image(OpenFlBitmapData.fromBitmapData(bitmap));
			image.x = 8 + i % 6 * 25; image.y = 8 + Std.int(i / 6) * 25;
			images.push(image); (i < 2 ? nested : sceneRoot).addChild(image);
		}
		backdrop = new Quad(180, 115, 0x242424);
		sceneRoot.addChildAt(backdrop, 0);
		mesh = new Graphics(); mesh.beginBitmapData(images[0].data); mesh.drawRect(160, 8, 8, 8);
		sceneRoot.addChildAt(mesh, 3);
		label = new Label("缓存验证 Ab12"); label.fontSize = 15; label.y = 125;
		sceneRoot.addChild(label);
		build();
	}

	private function build():Void {
		TextFieldRender.prepareLabel(label);
		sceneRoot.__updateTransform(null);
		cached.clear(); cached.renderDisplayObject(sceneRoot); cached.endFill();
		full.clear(); full.renderDisplayObject(sceneRoot); full.endFill();
	}

	private function checkFrame():Void {
		if (frame >= 96) return;
		var pixels:js.lib.Uint8Array = new js.lib.Uint8Array(384 * 192 * 4);
		untyped GL.context.readPixels(0, 0, 384, 192, GL.RGBA, GL.UNSIGNED_BYTE, pixels);
		var different:Int = 0;
		for (y in 0...192) for (x in 0...192) {
			var left:Int = (y * 384 + x) * 4;
			var right:Int = left + 192 * 4;
			for (channel in 0...4) if (pixels[left + channel] != pixels[right + channel]) different++;
			if (pixels[left] > 40 || pixels[left + 1] > 40 || pixels[left + 2] > 40) colored++;
		}
		if (different > 0) throw "第" + frame + "帧左右像素不同分量=" + different;
		checked++;
		frame++;
		if (frame == 96) {
			if (BufferBuildStats.reusedImages == 0) throw "浏览器验证未覆盖实际缓存命中";
			if (colored == 0) throw "未读取到实际绘制内容";
			untyped Browser.window.bufferResult = {frames:checked, colored:colored, reusedImages:BufferBuildStats.reusedImages, renderer:GL.getParameter(GL.RENDERER)};
			return;
		}
		var image:Image = images[frame % images.length];
		switch frame % 24 {
			case 0: image.visible = !image.visible;
			case 1: image.x += 2;
			case 2: sceneRoot.alpha = frame % 2 == 0 ? 0.7 : 1;
			case 3: image.colorTransform = new ColorTransform(0.6, 1, 0.8);
			case 4: sceneRoot.addChild(image);
			case 5: image.data.rect = new Rectangle(2, 2, 12, 12);
			case 6: image.smoothing = !image.smoothing;
			case 7: image.blendMode = ADD;
			case 8: label.data = "文字" + frame;
			case 9: sceneRoot.maskRect = new Rectangle(0, 0, 150, 150);
			case 10: sceneRoot.maskRect = null;
			case 11: image.colorTransform = null;
			case 12: nested.maskRect = new Rectangle(0, 0, 30, 25);
			case 13: nested.maskRect = null;
			case 14: cached.cacheAsBitmap = true; full.cacheAsBitmap = true;
			case 15: cached.cacheAsBitmap = false; full.cacheAsBitmap = false;
			case 16: image.shader = cast Render.defaultShader;
			case 17: for (value in images) value.shader = null;
			case 18: var filter:RenderFilter = new RenderFilter(); filter.render = images[0]; sceneRoot.filters = [filter];
			case 19: sceneRoot.filters = null;
			case 20: mesh.clear(); mesh.fillPath(new GraphicsPath().moveTo(152, 8).lineTo(180, 10).lineTo(169, 45).closePath(), 0x00cc88);
			case 21: mesh.clear(); mesh.beginBitmapData(images[0].data); for (i in 0...1 + frame % 3) mesh.drawRect(155 + i * 8, 20, 6, 9);
			case 22: backdrop.width = 165; images[5].scale9Grid = new Rectangle(2, 2, 8, 8); images[5].width = 24;
			case 23: backdrop.width = 180; images[5].scale9Grid = null;
		}
		build();
	}
}
