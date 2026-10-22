package hx.display.graphics;

/** 路径生成的本地网格；提交后只读，路径变化时生成新网格。 */
@:noCompletion
class GraphicsMesh {
	public var vertices:Array<Float> = [];
	public var indices:Array<Int> = [];
	public var uvs:Array<Float> = [];

	public function new() {}

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
