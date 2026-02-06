package hx.display;

import hx.geom.Rectangle;
import hx.geom.Matrix;

/**
 * 位图数据类，用于存储和管理位图信息
 * 封装了底层的位图实现，提供了统一的操作接口
 */
class BitmapData {
	/**
	 * 通过底层位图数据创建BitmapData实例
	 * @param data 底层位图数据接口实现
	 * @return 创建的BitmapData实例
	 */
	public static function formData(data:IBitmapData) {
		var bitmapData = new BitmapData();
		bitmapData.data = data;
		return bitmapData;
	}

	/**
	 * 底层位图数据
	 */
	public var data:IBitmapData;

	/**
	 * 位图切割区域
	 * 用于从原始位图中截取一部分
	 */
	public var rect:Rectangle;

	/**
	 * 位图的实际区域
	 * 表示位图在原始图像中的实际位置和大小
	 */
	public var frameRect:Rectangle;

	/**
	 * 九宫格缩放区域
	 * 用于定义位图的可缩放区域
	 */
	public var scale9Rect:Rectangle;

	/**
	 * 构造一个空的BitmapData实例
	 */
	public function new() {}

	/**
	 * UV偏移X坐标
	 * @return UV偏移X坐标值
	 */
	public var uvOffsetX(get, never):Float;

	/**
	 * 获取UV偏移X坐标
	 * @return UV偏移X坐标值
	 */
	private function get_uvOffsetX():Float {
		if (this.rect == null) {
			return 0;
		}
		return rect.x;
	}

	/**
	 * UV偏移Y坐标
	 * @return UV偏移Y坐标值
	 */
	public var uvOffsetY(get, never):Float;

	/**
	 * 获取UV偏移Y坐标
	 * @return UV偏移Y坐标值
	 */
	private function get_uvOffsetY():Float {
		if (this.rect == null) {
			return 0;
		}
		return rect.y;
	}

	/**
	 * 切割位图，创建一个新的BitmapData实例
	 * @param x 切割起始X坐标
	 * @param y 切割起始Y坐标
	 * @param width 切割宽度
	 * @param height 切割高度
	 * @return 切割后的新BitmapData实例
	 */
	public function sub(x:Float, y:Float, width:Float, height:Float):BitmapData {
		var bitmapData = BitmapData.formData(this.data);
		bitmapData.rect = new Rectangle(x, y, width, height);
		return bitmapData;
	}

	/**
	 * 位图宽度
	 * @return 位图的宽度
	 */
	public var width(get, never):Float;

	/**
	 * 获取位图宽度
	 * @return 位图的宽度
	 */
	@:noCompletion private function get_width():Float {
		if (frameRect != null) {
			return frameRect.width;
		} else if (rect != null) {
			return rect.width;
		} else {
			return data != null ? data.getWidth() : 0;
		}
	}

	/**
	 * 位图高度
	 * @return 位图的高度
	 */
	public var height(get, never):Float;

	/**
	 * 获取位图高度
	 * @return 位图的高度
	 */
	public function get_height():Float {
		if (frameRect != null) {
			return frameRect.height;
		} else if (rect != null) {
			return rect.height;
		} else {
			return data != null ? data.getHeight() : 0;
		}
	}

	/**
	 * 清空位图数据
	 */
	public function clear():Void {
		if (data != null) {
			data.clear();
		}
	}

	/**
	 * 绘制显示对象到位图
	 * @param source 要绘制的显示对象
	 * @param matrix 变换矩阵，默认为单位矩阵
	 * @param blendMode 混合模式，可选参数
	 * @param updateTransform 是否更新变换，默认为true
	 */
	public function draw(source:DisplayObject, matrix:Matrix = null, ?blendMode:BlendMode, updateTransform:Bool = true):Void {
		if (data != null && source != null) {
			data.draw(source, matrix == null ? new Matrix() : matrix, blendMode, updateTransform);
		}
	}

	/**
	 * 释放位图资源
	 * 当位图不再需要时调用，以释放底层资源
	 */
	public function dispose():Void {
		if (data != null) {
			data.dispose();
			data = null;
		}
	}
}
