package hx.core;

import openfl.display.Tile;
import openfl.geom.Rectangle;
import openfl.display.Tileset;
import openfl.display.Tilemap;
import openfl.utils.ObjectPool;
import openfl.Vector;
import openfl.display.Shape;
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
			if (display is Sprite) {
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
			}
		}
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
		if (image.data.rect != null) {
			bitmap.scrollRect = new Rectangle(image.data.rect.x, image.data.rect.y, image.data.rect.width, image.data.rect.height);
		}
		// 批处理状态渲染
		if (!state.push(bitmap)) {
			// 开始绘制
			this.drawBatchBitmapState();
			state.reset();
			state.push(bitmap);
		}
	}

	private var __pool:ObjectPool<Sprite> = new ObjectPool<Sprite>(() -> {
		return new Sprite();
	});

	/**
	 * 渲染纹理批处理状态
	 */
	private function drawBatchBitmapState():Void {
		if (state.bitmaps.length > 0) {
			// 图形绘制
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			shape.graphics.beginBitmapFill(state.bitmaps[0].bitmapData, null, false);
			var rects:Vector<Float> = new Vector();
			var transforms:Vector<Float> = new Vector();
			for (bitmap in state.bitmaps) {
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
		}
	}

	var tilemap:Tilemap = new Tilemap(0, 0);

	public function endFill():Void {
		this.drawBatchBitmapState();
	}
}
