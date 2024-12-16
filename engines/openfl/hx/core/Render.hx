package hx.core;

import openfl.text.TextFormat;
import openfl.text.TextField;
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

/**
 * OpenFL的渲染器支持
 */
@:access(hx.displays.DisplayObject)
class Render implements IRender {
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
	private var state:BatchBitmapState = new BatchBitmapState();

	public function new(engine:Engine) {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		this.engine = engine;
		this.engine.addChild(__stage);
		#if cpp
		engine.stage.frameRate = 61;
		#else
		engine.stage.frameRate = 60;
		#end
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
			if (object is Image) {
				renderImage(cast object);
			} else if (object is DisplayObjectContainer) {
				renderDisplayObjectContainer(cast object);
			} else if (object is Label) {
				this.drawBatchBitmapState();
				renderLabel(cast object);
			}
		}
		container.__dirty = false;
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
		}
		textField.x = label.__worldX;
		textField.y = label.__worldY;
		textField.rotation = label.__rotation;
		textField.alpha = label.__alpha;
		textField.scaleX = label.__scaleX;
		textField.scaleY = label.__scaleY;
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
		bitmap.x = image.__worldX;
		bitmap.y = image.__worldY;
		bitmap.rotation = image.__rotation;
		bitmap.alpha = image.__alpha;
		bitmap.scaleX = image.__scaleX;
		bitmap.scaleY = image.__scaleY;
		bitmap.bitmapData = image.data.data.getTexture();
		bitmap.smoothing = image.smoothing;
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
			shape.graphics.beginBitmapFill(lastBitmap.bitmapData, null, false, lastBitmap.smoothing);
			var rects:Vector<Float> = new Vector();
			var transforms:Vector<Float> = new Vector();
			for (bitmap in state.bitmaps) {
				if (bitmap.bitmapData == null)
					continue;
				if (bitmap.scrollRect != null) {
					rects.push(bitmap.scrollRect.x);
					rects.push(bitmap.scrollRect.y);
					rects.push(bitmap.scrollRect.width);
					rects.push(bitmap.scrollRect.height);
				} else {
					rects.push(0);
					rects.push(0);
					rects.push(bitmap.bitmapData.width);
					rects.push(bitmap.bitmapData.height);
				}
				transforms.push(bitmap.transform.matrix.a);
				transforms.push(bitmap.transform.matrix.b);
				transforms.push(bitmap.transform.matrix.c);
				transforms.push(bitmap.transform.matrix.d);
				transforms.push(bitmap.transform.matrix.tx);
				transforms.push(bitmap.transform.matrix.ty);
			}
			shape.graphics.drawQuads(rects, null, transforms);
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
