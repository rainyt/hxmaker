package hx.geometry;

/** 位于 XZ 平面、正面朝向 +Y 的平面。 */
class PlaneGeometry {
	public static function create(width:Float = 1, depth:Float = 1):Geometry3D {
		if (width <= 0 || depth <= 0) throw "平面尺寸必须大于零";
		var x = width / 2, z = depth / 2;
		return new Geometry3D([-x,0.,z, x,0.,z, x,0.,-z, -x,0.,-z], [0.,1.,1.,1.,1.,0.,0.,0.], [0,1,2,0,2,3]);
	}
}
