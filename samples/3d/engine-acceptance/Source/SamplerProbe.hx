package;

import hx.display.BitmapData;
import hx.display.CustomDisplayObject;
import hx.render3d.openfl.TextureBridge3D;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;

/** 仅在人工诊断模式创建；同步 GL 查询不进入性能基线。 */
@:access(openfl.display.OpenGLRenderer)
class SamplerProbe {
	public var prefix(default,null):CustomDisplayObject;
	public var before(default,null):CustomDisplayObject;
	public var after(default,null):CustomDisplayObject;
	public var end(default,null):CustomDisplayObject;
	public var verified(default,null):Int = 0;
	public var nearestFrames(default,null):Int = 0;
	public var linearFrames(default,null):Int = 0;
	public var afterSmoothing:Bool = true;
	public var failures(default,null):Array<String> = [];
	private var bitmap:BitmapData;
	private var snapshot:Array<Int>;
	private var listeners:Array<{sprite:openfl.display.Sprite,listener:RenderEvent->Void}> = [];
	private var previousRenderer:OpenGLRenderer;
	private var previousUpscaled:Bool;
	public function new(bitmap:BitmapData) {
		this.bitmap = bitmap;
		prefix=hook(function(renderer) {
			restore();
			previousRenderer=renderer; previousUpscaled=renderer.__upscaled; renderer.__upscaled=false;
		});
		before=hook(function(renderer) { snapshot=read(renderer); });
		after=hook(function(renderer) {
			var current=read(renderer);
			if (snapshot == null || current.join(":") != snapshot.join(":")) fail("三维前后采样参数不同："+snapshot+" -> "+current);
			else verified++;
		});
		end=hook(function(renderer) {
			var gl=renderer.gl, values=read(renderer);
			var expected=renderer.__allowSmoothing && afterSmoothing ? gl.LINEAR : gl.NEAREST;
			if (values[0] != expected || values[1] != expected) fail("二维后置贴图过滤不符合预期："+values+"，预期 "+expected);
			else if (expected == gl.NEAREST) nearestFrames++; else linearFrames++;
			restore();
		},true);
	}
	private function hook(callback:OpenGLRenderer->Void,restoreAfterError:Bool = false):CustomDisplayObject {
		var sprite=new openfl.display.Sprite();
		var listener:RenderEvent->Void=function(event) {
			var renderer:OpenGLRenderer=cast event.renderer;
			if (renderer.gl == null || renderer.gl.isContextLost()) { if (restoreAfterError) restore(); return; }
			try { callback(renderer); } catch (error:Dynamic) { fail(Std.string(error)); if (restoreAfterError) restore(); }
		};
		sprite.addEventListener(RenderEvent.RENDER_OPENGL,listener); listeners.push({sprite:sprite,listener:listener});
		return new CustomDisplayObject(sprite);
	}
	private function read(renderer:OpenGLRenderer):Array<Int> {
		var gl=renderer.gl, nativeBitmap:openfl.display.BitmapData=cast bitmap.data.getTexture();
		var texture=TextureBridge3D.resolve(nativeBitmap,renderer.__context3D);
		var previous=gl.getParameter(gl.TEXTURE_BINDING_2D);
		gl.bindTexture(gl.TEXTURE_2D,TextureBridge3D.handle(texture));
		var values:Array<Int>=[gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER),gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER),
			gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S),gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T)];
		gl.bindTexture(gl.TEXTURE_2D,previous); return values;
	}
	private function restore():Void { if (previousRenderer != null) { previousRenderer.__upscaled=previousUpscaled; previousRenderer=null; } }
	private function fail(message:String):Void { if (failures.indexOf(message)<0 && failures.length<20) failures.push(message); }
	public function dispose():Void {
		restore();
		for (entry in listeners) entry.sprite.removeEventListener(RenderEvent.RENDER_OPENGL,entry.listener);
		listeners=[]; bitmap=null; snapshot=null;
	}
}
