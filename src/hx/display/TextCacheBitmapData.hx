package hx.display;

class TextCacheBitmapData {
	public var size:Int = 36;

	public var textureWidth:Int = 2048;
	public var textureHeight:Int = 2048;
	public var offestX:Int = 1;
	public var offestY:Int = 1;

	public function new(size:Int = 36, textureWidth:Int = 2048, textureHeight:Int = 2048, offestX:Int = 1, offestY:Int = 1) {
		this.size = size;
		this.textureWidth = textureWidth;
		this.textureHeight = textureHeight;
		this.offestX = offestX;
		this.offestY = offestY;
	}
}
