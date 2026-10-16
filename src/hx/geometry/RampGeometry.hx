package hx.geometry;

import hx.render3d.Math3D;

/** 封闭楔形坡道：底面 Y=0，沿局部 +Z 从零升至 height，与 RampCollider3D 对齐。 */
class RampGeometry {
	public static function create(width:Float,height:Float,depth:Float):Geometry3D {
		for (value in [width,height,depth]) if (!Math3D.finite(value) || value <= 0) throw "坡道尺寸必须为正有限数值";
		var x = width/2, z = depth/2;
		var vertices = [[-x,0.,-z],[x,0.,-z],[-x,0.,z],[x,0.,z],[-x,height,z],[x,height,z]];
		var faces = [[0,1,3,2],[0,4,5,1],[2,3,5,4],[0,2,4],[1,5,3]];
		var positions:Array<Float> = [], uvs:Array<Float> = [], indices:Array<Int> = [];
		for (face in faces) {
			var base = Std.int(positions.length/3);
			for (i in 0...face.length) {
				for (value in vertices[face[i]]) positions.push(value);
				uvs.push(i == 1 || i == 2 ? 1 : 0); uvs.push(i >= 2 ? 0 : 1);
			}
			for (i in 1...(face.length-1)) { indices.push(base); indices.push(base+i); indices.push(base+i+1); }
		}
		return new Geometry3D(positions,uvs,indices);
	}
}
