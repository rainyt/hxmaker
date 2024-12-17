package hx.core;

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
	private var state:BatchBitmapState;

	/**
	 * 多纹理支持的纹理单元数量
	 */
	public var supportedMultiTextureUnits:Int = 1;

	public function new(engine:Engine) {
		this.state = new BatchBitmapState(this);
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
		for (i in 0...__stage.numChildren) {
			var display = __stage.getChildAt(i);
			if (display is EngineSprite) {
				__pool.release(cast display);
			}
		}
		__stage.removeChildren();
		state.reset();
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
		textField.text = label.data;
		if (label.__dirty) {
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

	/**
	 * 渲染Image对象
	 * @param image 
	 */
	public function renderImage(image:Image) {
		if (image.data == null)
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
			bitmap.scrollRect = new Rectangle(image.data.rect.x, image.data.rect.y, image.data.rect.width, image.data.rect.height);
		}
		// 批处理状态渲染
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
		if (state.bitmaps.length > 0) {
			// 图形绘制
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			var lastBitmap = state.bitmaps[0];
			// shape.graphics.beginBitmapFill(lastBitmap.bitmapData, null, false, lastBitmap.smoothing);
			var openfl_TextureId:ShaderParameter<Float> = defalutShader.data.openfl_TextureId;
			var ids = [];
			var mapIds:Map<BitmapData, Int> = [];
			for (index => data in state.bitmapDatas) {
				mapIds.set(data, index);
				var sampler:ShaderInput<BitmapData> = defalutShader.data.getProperty('uSampler$index');
				sampler.input = data;
			}
			var rects:Vector<Float> = new Vector();
			var transforms:Vector<Float> = new Vector();
			var ids:Array<Float> = [];
			var vertices:Vector<Float> = new Vector();
			var indices:Vector<Int> = new Vector();
			var uvtData:Vector<Float> = new Vector();
			var indicesOffset:Int = 0;
			for (bitmap in state.bitmaps) {
				if (bitmap.bitmapData == null)
					continue;
				var id = mapIds.get(bitmap.bitmapData);
				for (i in 0...6) {
					ids.push(id);
				}
				// if (bitmap.scrollRect != null) {
				// 	rects.push(bitmap.scrollRect.x);
				// 	rects.push(bitmap.scrollRect.y);
				// 	rects.push(bitmap.scrollRect.width);
				// 	rects.push(bitmap.scrollRect.height);
				// } else {
				// 	rects.push(0);
				// 	rects.push(0);
				// 	rects.push(bitmap.bitmapData.width);
				// 	rects.push(bitmap.bitmapData.height);
				// }
				// transforms.push(bitmap.transform.matrix.a);
				// transforms.push(bitmap.transform.matrix.b);
				// transforms.push(bitmap.transform.matrix.c);
				// transforms.push(bitmap.transform.matrix.d);
				// transforms.push(bitmap.transform.matrix.tx);
				// transforms.push(bitmap.transform.matrix.ty);

				// vertices
				var tileWidth:Float = bitmap.scrollRect != null ? bitmap.scrollRect.width : bitmap.bitmapData.width;
				var tileHeight:Float = bitmap.scrollRect != null ? bitmap.scrollRect.height : bitmap.bitmapData.height;
				var tileTransform = @:privateAccess bitmap.__transform;
				var x = tileTransform.__transformX(0, 0);
				var y = tileTransform.__transformY(0, 0);
				var x2 = tileTransform.__transformX(tileWidth, 0);
				var y2 = tileTransform.__transformY(tileWidth, 0);
				var x3 = tileTransform.__transformX(0, tileHeight);
				var y3 = tileTransform.__transformY(0, tileHeight);
				var x4 = tileTransform.__transformX(tileWidth, tileHeight);
				var y4 = tileTransform.__transformY(tileWidth, tileHeight);
				vertices.push(x);
				vertices.push(y);
				vertices.push(x2);
				vertices.push(y2);
				vertices.push(x3);
				vertices.push(y3);
				vertices.push(x4);
				vertices.push(y4);

				// indices
				indices.push(indicesOffset);
				indices.push(indicesOffset + 1);
				indices.push(indicesOffset + 2);
				indices.push(indicesOffset + 1);
				indices.push(indicesOffset + 2);
				indices.push(indicesOffset + 3);

				indicesOffset += 4;

				// UVs
				if (bitmap.scrollRect != null) {
					var uvX = bitmap.scrollRect.x / bitmap.bitmapData.width;
					var uvY = bitmap.scrollRect.y / bitmap.bitmapData.height;
					var uvW = (bitmap.scrollRect.x + bitmap.scrollRect.width) / bitmap.bitmapData.width;
					var uvH = (bitmap.scrollRect.y + bitmap.scrollRect.height) / bitmap.bitmapData.height;
					uvtData.push(uvX);
					uvtData.push(uvY);
					uvtData.push(uvW);
					uvtData.push(uvY);
					uvtData.push(uvX);
					uvtData.push(uvH);
					uvtData.push(uvW);
					uvtData.push(uvH);
				} else {
					uvtData.push(0);
					uvtData.push(0);
					uvtData.push(1);
					uvtData.push(0);
					uvtData.push(0);
					uvtData.push(1);
					uvtData.push(1);
					uvtData.push(1);
				}
			}
			// trace("ids.length", ids.length);
			// shape.graphics.drawQuads(rects, null, transforms);
			openfl_TextureId.value = ids;
			shape.graphics.beginShaderFill(defalutShader);
			shape.graphics.drawTriangles(vertices, indices, uvtData);
			shape.graphics.endFill();
			__stage.addChild(shape);
			state.reset();
		}
	}

	var tilemap:Tilemap = new Tilemap(0, 0);

	public function endFill():Void {
		this.drawBatchBitmapState();
	}
}
