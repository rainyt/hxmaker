package hx.display;

class TextFormat {
	/**
	 * 字体
	 */
	public var font:String = null;

	/**
	 * 文本的字体大小
	 */
	public var size:Int = 0;

	/**
	 * 文本的颜色
	 */
	public var color:Int = 0x0;

	/**
	 * 文本描边粗细
	 */
	public var outline:Int = 0;

	/**
	 * 文本描边颜色
	 */
	public var outlineColor:Int = 0x0;

	public function new(font:String = null, size:Int = 26, color:UInt = 0x0, outline:Int = 0, outlineColor:UInt = 0x0) {
		this.font = font;
		this.size = size;
		this.color = color;
		this.outline = outline;
		this.outlineColor = outlineColor;
	}

	/**
	 * 设置文本格式
	 * @param textFormat 
	 */
	public function setTo(textFormat:TextFormat):Void {
		this.size = textFormat.size;
		this.color = textFormat.color;
		this.outline = textFormat.outline;
		this.outlineColor = textFormat.outlineColor;
	}

	/**
	 * 克隆文本格式
	 * @return TextFormat
	 */
	public function clone():TextFormat {
		var format = new TextFormat();
		format.setTo(this);
		return format;
	}
}
