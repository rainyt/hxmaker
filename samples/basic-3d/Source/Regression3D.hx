package;

#if hxmaker_3d_regression
import hx.core.Hxmaker;
import hx.display.CustomDisplayObject;
import hx.display.Scene3D;
import hx.display.Camera3D;
import hx.display.MeshObject;
import hx.display.Label;
import hx.geometry.BoxGeometry;
import hx.material.UnlitTextureMaterial;
import hx.render3d.openfl.TextureBridge3D;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;

/** 独立诊断场景：实际读取 GL 验证共享采样状态，并手动触发上下文恢复。 */
@:access(openfl.display.OpenGLRenderer)
class Regression3D {
	private var source:openfl.display.BitmapData;
	private var before:Bitmap;
	private var after:Bitmap;
	private var snapshot:Array<Int>;
	private var frames:Int = 0;
	private var verified:Int = 0;
	public function new(source:openfl.display.BitmapData) {
		this.source = source;
		var stage = Hxmaker.topView;
		before = new Bitmap(source); before.scaleX = before.scaleY = 0.6;
		after = new Bitmap(source); after.scaleX = after.scaleY = 0.6;
		var front = new Sprite();
		// 诊断构建关闭自动放大平滑，保证二维两种采样模式都实际执行。
		front.addChild(probe(function(renderer) { renderer.__upscaled = false; }));
		front.addChild(before); front.addChild(probe(function(renderer) {
			snapshot = readSampler(renderer); frames++;
		}));
		var frontObject = new CustomDisplayObject(front); frontObject.x = 24; frontObject.y = 60;
		stage.addChildAt(frontObject, 1);
		var back = new Sprite();
		back.addChild(probe(function(renderer) {
			var actual = readSampler(renderer);
			if (snapshot == null || actual.join(":") != snapshot.join(":")) throw "三维绘制污染共享纹理采样状态：" + snapshot + " -> " + actual;
		}));
		back.addChild(after);
		back.addChild(probe(function(renderer) {
			var gl = renderer.gl, actual = readSampler(renderer), expected = renderer.__allowSmoothing && (after.smoothing || renderer.__upscaled) ? gl.LINEAR : gl.NEAREST;
			if (actual[0] != expected || actual[1] != expected) throw "二维纹理采样状态错误：" + actual + "，预期 " + expected;
			if (++verified == 120) trace("HXMAKER_3D_REGRESSION PASS 共享纹理连续 120 帧交替 NEAREST/LINEAR，三维前后状态一致");
		}));
		var backObject = new CustomDisplayObject(back); backObject.x = 70; backObject.y = 60; stage.addChild(backObject);
		stage.addEventListener(hx.events.Event.UPDATE, function(_) {
			before.smoothing = Std.int(frames / 30) % 2 == 0;
			after.smoothing = !before.smoothing;
		});
		var scene = new Scene3D(260, 110); scene.x = 660; scene.y = 85; scene.backgroundAlpha = 1; scene.backgroundColor = 0x405065;
		var camera = new Camera3D(); camera.z = 6; scene.root.addChild(camera); scene.camera = camera;
		for (i in 0...3) {
			var material = new UnlitTextureMaterial();
			material.fragmentDeclarations = "uniform vec3 uTint;"; material.fragmentCode = "color.rgb *= uTint;";
			if (i < 2) material.setUniform("uTint", i == 0 ? [1.,0.,0.] : [0.,1.,0.]);
			var mesh = new MeshObject(BoxGeometry.create(), material); mesh.x = (i - 1) * 1.5; scene.root.addChild(mesh);
		}
		stage.addChild(scene);
		#if hxmaker_3d_regression_2d_only
		scene.visible = false;
		#end
		var note = new Label("诊断：右上应为红、绿、黑；点击此处验证上下文恢复");
		note.fontSize = 14; note.color = 0xffffff; note.x = 24; note.y = 620; stage.addChild(note);
		note.addEventListener(hx.events.MouseEvent.CLICK, function(_) {
			#if (js && html5)
			var gl:Dynamic = openfl.Lib.current.stage.window.context.webgl;
			var extension:Dynamic = gl.getExtension("WEBGL_lose_context");
			if (extension == null) { trace("HXMAKER_3D_REGRESSION 当前浏览器不支持主动丢失上下文"); return; }
			verified = 0; frames = 0; snapshot = null;
			trace("HXMAKER_3D_REGRESSION 主动丢失上下文"); extension.loseContext();
			haxe.Timer.delay(function() { trace("HXMAKER_3D_REGRESSION 请求恢复上下文"); extension.restoreContext(); }, 300);
			#end
		});
	}
	private function probe(callback:OpenGLRenderer->Void):Sprite {
		var sprite = new Sprite();
		sprite.addEventListener(RenderEvent.RENDER_OPENGL, function(event:RenderEvent) { var renderer:OpenGLRenderer = cast event.renderer; if (renderer.gl == null || renderer.gl.isContextLost()) return;
			try { callback(renderer); } catch (error:Dynamic) { trace(Std.string(error)); throw error; } });
		return sprite;
	}
	/** 独立检查真实 GL 参数，读完恢复绑定，不依赖被测状态守卫。 */
	private function readSampler(renderer:OpenGLRenderer):Array<Int> {
		var gl = renderer.gl, texture = TextureBridge3D.resolve(source, renderer.__context3D);
		var previous = gl.getParameter(gl.TEXTURE_BINDING_2D);
		gl.bindTexture(gl.TEXTURE_2D, TextureBridge3D.handle(texture));
		var result:Array<Int> = [gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER), gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER),
			gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S), gl.getTexParameter(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T)];
		gl.bindTexture(gl.TEXTURE_2D, previous); return result;
	}
}
#end
