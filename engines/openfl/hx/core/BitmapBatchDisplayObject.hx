package hx.core;

import openfl.display3D.Context3D;
import openfl.display.ShaderParameter;
import openfl.Lib;
import openfl.display.OpenGLRenderer;
import openfl.events.RenderEvent;
import openfl.display.DisplayObject;
import openfl.utils._internal.Float32Array;
import openfl.display._internal.Context3DBuffer;

class BitmapBatchDisplayObject extends DisplayObject {
	/**
	 * 渲染状态
	 */
	public var state:BatchBitmapState;

	/**
	 * 渲染器
	 */
	public var render:Render;

	private var __buffer:Context3DBuffer;

	private var vertexBufferData:Float32Array;

	private var dataPerVertex:Int = 0;

	public function new() {
		super();
		this.addEventListener(RenderEvent.RENDER_OPENGL, onRenderOpenGL);
	}

	private function resizeBuffer(context:Context3D):Void {
		if (__buffer == null) {
			__buffer = new Context3DBuffer(context, QUADS, 0, dataPerVertex);
		} else {
			__buffer.resize(0, dataPerVertex);
		}
		vertexBufferData = __buffer.vertexBufferData;
	}

	private function onRenderOpenGL(e:RenderEvent):Void {
		var renderer:OpenGLRenderer = cast e.renderer;
		var context = Lib.application.window.stage.context3D;
		var openfl_TextureId:ShaderParameter<Float> = render.defalutShader.data.openfl_TextureId;
		var openfl_Alpha:ShaderParameter<Float> = render.defalutShader.data.openfl_Alpha_multi;
		openfl_TextureId.value = state.ids;
		openfl_Alpha.value = state.alphas;
		renderer.setShader(render.defalutShader);
		renderer.updateShader();
	}
}
