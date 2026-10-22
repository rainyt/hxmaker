package hx.display.graphics;

/** 描边几何样式；颜色、宽度和透明度由 strokePath 单独指定。 */
class GraphicsStrokeStyle {
	public var cap:GraphicsLineCap;
	public var join:GraphicsLineJoin;
	/** 斜接长度与半线宽的最大比值；超出后改用削角。 */
	public var miterLimit:Float;

	public function new(cap:GraphicsLineCap = BUTT, join:GraphicsLineJoin = MITER, miterLimit:Float = 4) {
		this.cap = cap;
		this.join = join;
		this.miterLimit = miterLimit;
	}

	@:noCompletion public function validate():Void {
		if (cap != BUTT && cap != SQUARE && cap != ROUND)
			throw "不支持的描边端点类型";
		if (join != MITER && join != BEVEL && join != ROUND)
			throw "不支持的描边转角类型";
		if (!Math.isFinite(miterLimit) || miterLimit < 1)
			throw "斜接限制必须是大于或等于 1 的有限数值";
	}
}
