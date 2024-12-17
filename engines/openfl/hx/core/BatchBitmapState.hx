package hx.core;

import openfl.display.BitmapData;
import openfl.display.Bitmap;

/**
 * 批处理位图渲染支持
 */
class BatchBitmapState {
	/**
	 * 待渲染的位图数据列表
	 */
	public var bitmaps:Array<Bitmap> = [];

	/**
	 * 待渲染的纹理数据列表
	 */
	public var bitmapDatas:Array<BitmapData> = [];

	public var render:Render;

	public function new(render:Render) {
		this.render = render;
	}

	/**
	 * 重置
	 */
	public function reset():Void {
		bitmaps = [];
		bitmapDatas = [];
	}

	/**
	 * 如果使用的资产是相同的，则追加成功
	 * @param bitmap 
	 * @return Bool
	 */
	public function push(bitmap:Bitmap):Bool {
		if (checkState(bitmap)) {
			bitmaps.push(bitmap);
			return true;
		}
		return false;
	}

	/**
	 * 检查状态是否可以合并
	 * @param bitmap 
	 * @return Bool
	 */
	public function checkState(bitmap:Bitmap):Bool {
		if (bitmaps.length == 0 || bitmapDatas.indexOf(bitmap.bitmapData) == -1) {
			// 多纹理支持，如果承载的多纹理数量允许，则可以继续添加
			if (bitmapDatas.length >= render.supportedMultiTextureUnits) {
				return false;
			} else {
				bitmapDatas.push(bitmap.bitmapData);
			}
		} else {
			var lastBitmap = bitmaps[bitmaps.length - 1];
			if (lastBitmap.smoothing != bitmap.smoothing) {
				return false;
			}
		}
		return true;
	}
}
