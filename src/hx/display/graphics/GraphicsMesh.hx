package hx.display.graphics;

/** 路径生成的本地网格；提交后只读，路径变化时生成新网格。 */
@:noCompletion
class GraphicsMesh {
	public var vertices:Array<Float> = [];
	public var indices:Array<Int> = [];
	public var uvs:Array<Float> = [];
	/** 每顶点边缘覆盖率；为空时全部为 1，复用后端已有的透明度通道。 */
	public var coverage:Array<Float>;
	private var cachedAntialias:GraphicsMesh;
	private var cachedAntialiasKey:String;

	public function new() {}

	/** 按本地坐标到最终物理像素的线性变换缓存过渡网格，平移不影响缓存。 */
	public function getAntialiased(a:Float, b:Float, c:Float, d:Float, width:Float):GraphicsMesh {
		var key = a + ":" + b + ":" + c + ":" + d + ":" + width;
		if (cachedAntialias == null || cachedAntialiasKey != key) {
			cachedAntialias = GraphicsAntialiaser.build(this, a, b, c, d, width);
			cachedAntialiasKey = key;
		}
		return cachedAntialias;
	}

	/** 增量折线修改顶点后需要显式丢弃过渡缓存。 */
	public function invalidateAntialias():Void {
		cachedAntialias = null;
		cachedAntialiasKey = null;
	}

	public function addVertex(x:Float, y:Float):Int {
		if (!Math.isFinite(x) || !Math.isFinite(y))
			throw "路径生成的顶点超出了有效数值范围";
		if (vertices.length >= 131070)
			throw "路径网格超过了 65535 个顶点，请拆分路径或降低精度";
		var index = Std.int(vertices.length / 2);
		vertices.push(x);
		vertices.push(y);
		uvs.push(0);
		uvs.push(0);
		return index;
	}

	public function triangle(a:Int, b:Int, c:Int):Void {
		indices.push(a);
		indices.push(b);
		indices.push(c);
	}
}
