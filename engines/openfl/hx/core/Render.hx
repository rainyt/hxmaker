package hx.core;

import openfl.geom.ColorTransform;
import openfl.display.ShaderInput;
import js.html.webgl.Sampler;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import lime.graphics.opengl.GL;
import openfl.display.Shader;
import hx.displays.DisplayObject;
import openfl.geom.Matrix;
import hx.displays.Quad;
import openfl.text.TextFormat;
import hx.displays.Label;
import openfl.geom.Rectangle;
import openfl.display.Tilemap;
import openfl.utils.ObjectPool;
import openfl.Vector;
import hx.displays.Image;
import hx.displays.DisplayObjectContainer;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import hx.displays.IRender;

using Reflect;

/**
 * OpenFL的渲染器支持
 */
@:access(hx.displays.DisplayObject)
@:access(openfl.geom.Matrix)
class Render implements IRender {
	/**
	 * 默认的着色器支持
	 */
	public var defalutShader:Shader;

	/**
	 * 在OpenFL中渲染的舞台对象
	 */
	@:noCompletion private var __stage:Sprite = new Sprite();

	private var __pool:ObjectPool<EngineSprite> = new ObjectPool<EngineSprite>(() -> {
		return new EngineSprite();
	});

	/**
	 * 游戏引擎对象
	 */
	public var engine:Engine;

	/**
	 * 位图批渲染状态处理支持
	 */
	private var states:Array<BatchBitmapState> = [];

	/**
	 * 当前位图批渲染索引
	 */
	private var __currentStateIndex = 0;

	/**
	 * 多纹理支持的纹理单元数量
	 */
	public var supportedMultiTextureUnits:Int = 1;

	public function new(engine:Engine) {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		this.engine = engine;
		this.engine.addChild(__stage);
		#if cpp
		engine.stage.frameRate = 61;
		#else
		engine.stage.frameRate = 60;
		#end
		// 使用多纹理支持
		var maxCombinedTextureImageUnits:Int = GL.getParameter(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS);
		var maxTextureImageUnits:Int = GL.getParameter(GL.MAX_TEXTURE_IMAGE_UNITS);
		supportedMultiTextureUnits = Math.floor(Math.min(maxCombinedTextureImageUnits, maxTextureImageUnits));
		defalutShader = new MultiTextureShader(supportedMultiTextureUnits);
	}

	public function clear():Void {
		// 清理舞台
		__currentStateIndex = 0;
		for (i in 0...__stage.numChildren) {
			var display = __stage.getChildAt(i);
			if (display is EngineSprite) {
				__pool.release(cast display);
			}
		}
		for (state in states) {
			state.reset();
		}
		if (states[__currentStateIndex] == null) {
			states[__currentStateIndex] = new BatchBitmapState(this);
		}
		__stage.removeChildren();
	}

	public function renderDisplayObjectContainer(container:DisplayObjectContainer) {
		for (object in container.children) {
			if (!object.visible || object.alpha == 0) {
				continue;
			}
			if (object is Image) {
				renderImage(cast object);
			} else if (object is DisplayObjectContainer) {
				renderDisplayObjectContainer(cast object);
			} else if (object is Label) {
				this.drawBatchBitmapState();
				renderLabel(cast object);
			} else if (object is Quad) {
				this.drawBatchBitmapState();
				renderQuad(cast object);
			}
		}
		container.__dirty = false;
	}

	/**
	 * 渲染矩阵
	 * @param quad 
	 */
	public function renderQuad(quad:Quad):Void {
		if (quad.root == null) {
			quad.root = new Sprite();
			quad.setDirty();
		}
		var sprite:Sprite = quad.root;
		sprite.graphics.clear();
		sprite.graphics.beginFill(quad.data);
		sprite.graphics.drawRect(0, 0, quad.width, quad.height);
		sprite.transform.matrix = getMarix(quad);
		sprite.alpha = quad.__worldAlpha;
		__stage.addChild(sprite);
	}

	public function getMarix(display:DisplayObject):Matrix {
		var hm:hx.gemo.Matrix = display.__worldTransform;
		var m = new Matrix(hm.a, hm.b, hm.c, hm.d, hm.tx, hm.ty);
		return m;
	}

	/**
	 * 渲染Label对象
	 * @param image 
	 */
	public function renderLabel(label:Label):Void {
		if (label.root == null) {
			label.root = new EngineTextField();
			label.setDirty();
		}
		var textField:EngineTextField = cast label.root;
		if (label.data != null && textField.text != label.data) {
			textField.text = label.data;
			var format:hx.displays.TextFormat = label.__textFormat;
			textField.setTextFormat(new TextFormat(format.font, format.size, format.color));
			label.updateAlignTranform();
			label.__updateTransform(label.parent);
		}
		textField.alpha = label.__worldAlpha;
		textField.transform.matrix = getMarix(label);
		textField.width = label.width;
		textField.height = label.height;
		label.__dirty = false;
		__stage.addChild(textField);
	}

	private var __rect:Rectangle = new Rectangle();

	/**
	 * 渲染Image对象
	 * @param image 
	 */
	public function renderImage(image:Image) {
		if (image.data == null || image.data.data == null)
			return;
		if (image.root == null) {
			image.root = new Bitmap();
		}
		var bitmap:Bitmap = image.root;
		bitmap.alpha = image.__worldAlpha;
		bitmap.bitmapData = image.data.data.getTexture();
		bitmap.smoothing = image.smoothing;
		bitmap.transform.matrix = getMarix(image);
		image.__dirty = false;
		if (image.data.rect != null) {
			__rect.x = image.data.rect.x;
			__rect.y = image.data.rect.y;
			__rect.width = image.data.rect.width;
			__rect.height = image.data.rect.height;
			bitmap.scrollRect = __rect;
		} else if (bitmap.scrollRect != null) {
			bitmap.scrollRect = null;
		}
		// 批处理状态渲染
		var state = states[__currentStateIndex];
		if (!state.push(bitmap)) {
			// 开始绘制
			this.drawBatchBitmapState();
			state.push(bitmap);
		}
	}

	/**
	 * 渲染纹理批处理状态
	 */
	private function drawBatchBitmapState():Void {
		var state = states[__currentStateIndex];
		if (state.bitmapIndex > 0) {
			#if custom_render
			var bitmapBatch = new BitmapBatchDisplayObject();
			bitmapBatch.state = state;
			bitmapBatch.render = this;
			this.__stage.addChild(bitmapBatch);
			#else
			// 图形绘制
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			var lastBitmap = state.bitmaps[0];
			var openfl_TextureId:ShaderParameter<Float> = defalutShader.data.openfl_TextureId;
			var openfl_Alpha:ShaderParameter<Float> = defalutShader.data.openfl_Alpha_multi;
			var offests:Array<Float> = [];
			var mapIds:Map<BitmapData, Int> = [];
			for (index => data in state.bitmapDatas) {
				mapIds.set(data, index);
				var sampler:ShaderInput<BitmapData> = defalutShader.data.getProperty('uSampler$index');
				sampler.input = data;
			}
			openfl_TextureId.value = state.ids;
			openfl_Alpha.value = state.alphas;
			shape.graphics.beginShaderFill(defalutShader);
			shape.graphics.drawTriangles(state.vertices, state.indices, state.uvtData);
			shape.graphics.endFill();
			__stage.addChild(shape);
			#end
			__currentStateIndex++;
			if (states[__currentStateIndex] == null) {
				states[__currentStateIndex] = new BatchBitmapState(this);
			}
		}
	}

	var tilemap:Tilemap = new Tilemap(0, 0);

	public function endFill():Void {
		this.drawBatchBitmapState();
	}
}
