package hx.display;

class TextCacheBitmapData {
	public var size:Int = 36;

	/**
	 * 单页纹理的尺寸，必须是 2 的幂（打包器的要求）
	 */
	public var textureWidth:Int = 1024;
	public var textureHeight:Int = 1024;
	public var offestX:Int = 1;
	public var offestY:Int = 1;

	/**
	 * 允许分配的最大纹理页数。
	 *
	 * 文本图集由若干页组成，页内写满后不会再擦除重排，而是新开一页，
	 * 所以页数决定了这个缓存器的字形容量上限：
	 * **每页 = 一张`textureWidth × textureHeight`的纹理，1024×1024 的 RGBA 约 4MB 显存，
	 * 并且在本帧的渲染批次里占用一个纹理单元**。
	 * 达到上限后新的字形会被丢弃（缺字，不会出现乱码），并通过回调通知一次。
	 *
	 * 如果文本量特别大（例如长期滚动的聊天记录），可以调大此值；
	 * 更推荐的做法是在切场景等安全时机调用`Label.clearTextFieldContextBitmapData`回收图集。
	 */
	public var maxPages:Int = 4;

	public function new(size:Int = 36, textureWidth:Int = 1024, textureHeight:Int = 1024, offestX:Int = 1, offestY:Int = 1, maxPages:Int = 4) {
		this.size = size;
		this.textureWidth = textureWidth;
		this.textureHeight = textureHeight;
		this.offestX = offestX;
		this.offestY = offestY;
		this.maxPages = maxPages;
	}
}
