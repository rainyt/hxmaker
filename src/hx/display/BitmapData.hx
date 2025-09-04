package hx.display;

import hx.geom.Rectangle;

/**
 * 位图显示对象
 */
class BitmapData {
	/**
	 * 通过data返回的位图数据
	 * @param data 
	 */
	public static function formData(data:IBitmapData) {
		var bitmapData = new BitmapData();
		bitmapData.data = data;
		return bitmapData;
	}

	/**
	 * 位图数据
	 */
	public var data:IBitmapData;

	/**
	 * 位图切割区域
	 */
	public var rect:Rectangle;

	/**
	 * 位图的实际区域
	 */
	public var frameRect:Rectangle;

	/**
	 * 九宫格缩放区域
	 */
	public var scale9Rect:Rectangle;

	public function new() {}

	public var uvOffsetX(get, never):Float;

	private function get_uvOffsetX():Float {
		if (this.rect == null) {
			return 0;
		}
		return rect.x;
	}

	public var uvOffsetY(get, never):Float;

	private function get_uvOffsetY():Float {
		if (this.rect == null) {
			return 0;
		}
		return rect.y;
	}

	/**
	 * 切割位图
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 * @return BitmapData
	 */
	public function sub(x:Float, y:Float, width:Float, height:Float):BitmapData {
		var bitmapData = BitmapData.formData(this.data);
		bitmapData.rect = new Rectangle(x, y, width, height);
		return bitmapData;
	}

	public var width(get, never):Float;

	@:noCompletion private function get_width():Float {
		if (frameRect != null) {
			return frameRect.width;
		} else if (rect != null) {
			return rect.width;
		} else {
			return data != null ? data.getWidth() : 0;
		}
	}

	public var height(get, never):Float;

	public function get_height():Float {
		if (frameRect != null) {
			return frameRect.height;
		} else if (rect != null) {
			return rect.height;
		} else {
			return data != null ? data.getHeight() : 0;
		}
	}
}
