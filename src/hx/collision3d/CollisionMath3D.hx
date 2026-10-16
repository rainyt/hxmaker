package hx.collision3d;

import hx.geom.Bounds3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 竖直胶囊对世界 AABB 的解析距离；不读取渲染网格。 */
class CollisionMath3D {
	public static function vector(value:Vector3D):Void {
		if (value == null || !Math3D.finite(value.x) || !Math3D.finite(value.y) || !Math3D.finite(value.z)) throw "碰撞向量必须为有限数值";
	}
	public static function capsule(center:Vector3D,radius:Float,height:Float):Void {
		vector(center);
		if (!Math3D.finite(radius) || !Math3D.finite(height) || radius <= 0 || height < radius*2) throw "胶囊半径必须为正，总高度至少为直径";
	}
	public static inline function clamp(value:Float,lo:Float,hi:Float):Float { return Math.max(lo,Math.min(hi,value)); }
	/** 胶囊中心线沿 Y 延展，等价于球心对沿 Y 扩展后的箱体求距。 */
	public static function sample(center:Vector3D,radius:Float,height:Float,box:Bounds3D):CapsuleBoxSample3D {
		var half = height/2-radius, low = box.min.y-half, high = box.max.y+half;
		var dx = center.x-clamp(center.x,box.min.x,box.max.x), dy = center.y-clamp(center.y,low,high), dz = center.z-clamp(center.z,box.min.z,box.max.z);
		var distance = Math.sqrt(dx*dx+dy*dy+dz*dz), normal = new Vector3D();
		if (!Math3D.finite(distance) || !Math3D.finite(low) || !Math3D.finite(high)) throw "碰撞计算超出有限范围";
		var separation:Float;
		if (distance > 1e-12) { normal.setTo(dx/distance,dy/distance,dz/distance); separation = distance-radius; }
		else {
			var distances = [center.x-box.min.x,box.max.x-center.x,center.y-low,high-center.y,center.z-box.min.z,box.max.z-center.z];
			var side = 0; for (i in 1...6) if (distances[i] < distances[side]) side = i;
			switch (side) {
				case 0: normal.x = -1; case 1: normal.x = 1; case 2: normal.y = -1;
				case 3: normal.y = 1; case 4: normal.z = -1; case 5: normal.z = 1;
			}
			separation = -radius-distances[side];
		}
		var point = new Vector3D(clamp(center.x,box.min.x,box.max.x),clamp(center.y,box.min.y,box.max.y),clamp(center.z,box.min.z,box.max.z));
		// 箱内退化情况选择推出方向对应的真实箱体表面。
		if (distance <= 1e-12) {
			if (normal.x != 0) point.x = normal.x < 0 ? box.min.x : box.max.x;
			if (normal.y != 0) point.y = normal.y < 0 ? box.min.y : box.max.y;
			if (normal.z != 0) point.z = normal.z < 0 ? box.min.z : box.max.z;
		}
		return {separation:separation,normal:normal,point:point};
	}
}

typedef CapsuleBoxSample3D = { var separation:Float; var normal:Vector3D; var point:Vector3D; }
