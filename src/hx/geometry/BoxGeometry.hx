package hx.geometry;

/** 六面立方体，每个面独立顶点，正面绕序为逆时针。 */
class BoxGeometry {
	/** 创建以原点为中心的箱体网格；宽、高、深为正的局部尺寸。 */
	public static function create(width:Float = 1, height:Float = 1, depth:Float = 1):Geometry3D {
		if (width <= 0 || height <= 0 || depth <= 0)
			throw "立方体尺寸必须大于零";
		var x = width / 2, y = height / 2, z = depth / 2;
		// 六个面各保留一行顶点，方便核对绕序与 UV。
		// @formatter:off
		var positions = [
			-x, -y, z,  x, -y, z,  x, y, z,  -x, y, z, 
			x, -y, -z,  -x, -y, -z,  -x, y, -z,  x, y, -z, 
			x, -y, z,  x, -y, -z,  x, y, -z,  x, y, z, 
			-x, -y, -z,  -x, -y, z,  -x, y, z,  -x, y, -z, 
			-x, y, z,  x, y, z,  x, y, -z,  -x, y, -z, 
			-x, -y, -z,  x, -y, -z,  x, -y, z,  -x, -y, z
		];
		// @formatter:on
		var uvs:Array<Float> = [], indices:Array<Int> = [];
		for (face in 0...6) {
			for (value in [0., 1., 1., 1., 1., 0., 0., 0.])
				uvs.push(value);
			for (index in [0, 1, 2, 0, 2, 3])
				indices.push(face * 4 + index);
		}
		return new Geometry3D(positions, uvs, indices);
	}
}
