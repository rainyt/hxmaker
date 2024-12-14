package hx.core;

import openfl.Vector;
import openfl.display.Shape;
import hx.displays.Image;
import hx.displays.DisplayObjectContainer;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import hx.displays.Stage;
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
		this.engine = engine;
		this.engine.addChild(__stage);
	}

	public function clear():Void {
		// 清理舞台
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
		// __stage.addChild(bitmap);
		if (!state.push(bitmap)) {
			// 开始绘制
			this.drawBatchBitmapState();
			state.reset();
			state.push(bitmap);
		}
	}

	private function drawBatchBitmapState():Void {
		if (state.bitmaps.length > 0) {
			var shape:Shape = new Shape();
			shape.graphics.beginBitmapFill(state.bitmaps[0].bitmapData);
			var rects:Vector<Float> = new Vector();
			var transforms:Vector<Float> = new Vector();
			for (bitmap in state.bitmaps) {
				rects.push(0);
				rects.push(0);
				rects.push(bitmap.width);
				rects.push(bitmap.height);
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

	public function endFill():Void {
		this.drawBatchBitmapState();
	}
}
