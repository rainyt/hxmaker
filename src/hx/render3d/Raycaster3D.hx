package hx.render3d;

import hx.display.MeshObject;
import hx.display.Node3D;
import hx.events.PickResult3D;
import hx.geom.Matrix3D;
import hx.geom.Point;
import hx.geom.Ray3D;
import hx.geom.Vector3D;

/** 与平台和视口无关的最近几何命中；透明像素与二维遮罩不参与查询。 */
class Raycaster3D {
	/** maxDistance 从射线起点计算；可选视图投影用于视口近远裁剪。 */
	public static function intersect(root:Node3D, ray:Ray3D, maxDistance:Null<Float> = null,
		filter:MeshObject->Bool = null, viewProjection:Matrix3D = null):PickResult3D {
		var limit:Float = maxDistance == null ? Math.POSITIVE_INFINITY : maxDistance;
		if (ray == null || Math.isNaN(limit) || limit < 0) throw "射线查询参数无效";
		// 公开向量可能被调用方修改，查询时重新验证并归一化，不修改源射线。
		var worldRay = new Ray3D(ray.origin, ray.direction);
		if (root == null || !root.isWorldVisible()) return null;
		var best:PickResult3D = null;
		function visit(node:Node3D):Void {
			if (!node.visible || node.isDisposed) return;
			if (Std.isOfType(node, MeshObject)) {
				var mesh:MeshObject = cast node;
				if (mesh.pickable && mesh.geometry != null && mesh.material != null && (filter == null || filter(mesh))
					&& worldRay.intersectsBounds(mesh.getWorldBounds())) {
					var world = mesh.getWorldMatrix(), inverse = world.clone();
					if (Math.abs(world.determinant) >= 1e-12 && inverse.invert()) {
						var local = new Ray3D(inverse.transformVector(worldRay.origin), inverse.deltaTransformVector(worldRay.direction));
						var g = mesh.geometry, a = new Vector3D(), b = new Vector3D(), c = new Vector3D();
						for (triangle in 0...Std.int(g.indices.length / 3)) {
							var ia = g.indices[triangle*3], ib = g.indices[triangle*3+1], ic = g.indices[triangle*3+2];
							a.setTo(g.positions[ia*3],g.positions[ia*3+1],g.positions[ia*3+2]);
							b.setTo(g.positions[ib*3],g.positions[ib*3+1],g.positions[ib*3+2]);
							c.setTo(g.positions[ic*3],g.positions[ic*3+1],g.positions[ic*3+2]);
							var hit = local.intersectTriangle(a,b,c);
							if (hit == null) continue;
							var point = world.transformVector(local.at(hit[0])), distance = point.subtract(worldRay.origin).length;
							if (!Math3D.finite(distance) || distance > limit || (best != null && distance >= best.distance)) continue;
							if (viewProjection != null) {
								var clip = viewProjection.transformVector(point);
								if (clip.w <= 0 || clip.z < -clip.w || clip.z > clip.w) continue;
							}
							var u = hit[1], v = hit[2], w = 1-u-v;
							var uv = new Point(g.uvs[ia*2]*w+g.uvs[ib*2]*u+g.uvs[ic*2]*v,
								g.uvs[ia*2+1]*w+g.uvs[ib*2+1]*u+g.uvs[ic*2+1]*v);
							best = new PickResult3D(mesh,point,distance,triangle,uv);
						}
					}
				}
			}
			for (child in node.children) visit(child);
		}
		visit(root); return best;
	}
}
