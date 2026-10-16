package hx.collision3d;

import hx.collision3d.TriangleDistance3D.TrianglePair3D;
import hx.display.Node3D;
import hx.geom.Bounds3D;
import hx.geom.Ray3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 封闭凸楔形代理，沿局部 +Z 升高；在世界空间求距，支持可逆仿射节点变换。 */
class RampCollider3D extends Collider3D {
	public var size:Vector3D;
	private var triangles:Array<RampTriangle3D> = [];
	private var planes:Array<RampPlane3D> = [];
	private var bounds:Bounds3D;
	private var cachedNode:Node3D;
	private var cachedVersion:Int = -1;
	private var settings:Array<Float> = [];
	public function new(width:Float,height:Float,depth:Float,node:Node3D = null) {
		super(node); size = new Vector3D(width,height,depth); validate();
	}
	override public function validate():Void {
		super.validate(); CollisionMath3D.vector(size);
		if (size.x <= 0 || size.y <= 0 || size.z <= 0) throw "坡道尺寸必须为正";
	}
	private function refresh():Void {
		validate(); if (node != null && node.isDisposed) throw "坡道节点已经销毁";
		var matrix = node == null ? null : node.getWorldMatrix(), version = node == null ? 0 : node.worldVersion;
		var values = [size.x,size.y,size.z,offset.x,offset.y,offset.z], dirty = triangles.length == 0 || cachedNode != node || cachedVersion != version;
		for (i in 0...values.length) if (settings.length != values.length || settings[i] != values[i]) dirty = true;
		if (!dirty) return;
		if (matrix != null && Math.abs(matrix.determinant) < 1e-12) throw "坡道节点变换不可退化";
		var x = size.x/2, z = size.z/2;
		var local = [new Vector3D(-x,0,-z),new Vector3D(x,0,-z),new Vector3D(-x,0,z),new Vector3D(x,0,z),new Vector3D(-x,size.y,z),new Vector3D(x,size.y,z)];
		var points:Array<Vector3D> = [], nextBounds = new Bounds3D(), middle = new Vector3D();
		for (p in local) {
			var v = p.add(offset); if (matrix != null) v = matrix.transformVector(v); CollisionMath3D.vector(v);
			points.push(v); nextBounds.include(v.x,v.y,v.z); middle = middle.add(v);
		}
		middle.scaleBy(1/6);
		CollisionMath3D.vector(middle);
		var nextTriangles:Array<RampTriangle3D> = [], nextPlanes:Array<RampPlane3D> = [];
		for (face in [[0,1,3,2],[0,4,5,1],[2,3,5,4],[0,2,4],[1,5,3]]) {
			var a = points[face[0]], b = points[face[1]], c = points[face[2]], normal = b.subtract(a).crossProduct(c.subtract(a));
			if (!Math3D.finite(normal.length) || normal.length < 1e-12) throw "坡道表面退化或超出数值范围";
			normal.normalize(); if (normal.dotProduct(middle.subtract(a)) > 0) normal.scaleBy(-1);
			nextPlanes.push({normal:normal,constant:-normal.dotProduct(a)});
			for (i in 1...(face.length-1)) nextTriangles.push({a:a,b:points[face[i]],c:points[face[i+1]],normal:normal});
		}
		triangles = nextTriangles; planes = nextPlanes; bounds = nextBounds; cachedNode = node; cachedVersion = version; settings = values;
	}
	override public function getWorldBounds():Bounds3D {
		refresh(); var result = new Bounds3D(); result.include(bounds.min.x,bounds.min.y,bounds.min.z); result.include(bounds.max.x,bounds.max.y,bounds.max.z); return result;
	}
	private function lineIntersects(start:Vector3D,end:Vector3D):Bool {
		var near = 0., far = 1.;
		for (plane in planes) {
			var a = plane.normal.dotProduct(start)+plane.constant, b = plane.normal.dotProduct(end)+plane.constant;
			if (a > 0 && b > 0) return false;
			if (a <= 0 && b <= 0) continue;
			var t = a/(a-b); if (a > b) near = Math.max(near,t); else far = Math.min(far,t);
			if (near > far) return false;
		}
		return true;
	}
	override public function sampleCapsule(center:Vector3D,radius:Float,height:Float):CollisionSample3D {
		refresh(); var half = height/2-radius, start = new Vector3D(center.x,center.y-half,center.z), end = new Vector3D(center.x,center.y+half,center.z);
		var best:TrianglePair3D = null, face:Vector3D = null;
		for (triangle in triangles) {
			var pair = TriangleDistance3D.segmentTriangle(start,end,triangle.a,triangle.b,triangle.c);
			if (best == null || pair.distanceSquared < best.distanceSquared-1e-16 || (Math.abs(pair.distanceSquared-best.distanceSquared) <= 1e-16 && triangle.normal.y > face.y)) {
				best = pair; face = triangle.normal;
			}
		}
		if (!Math3D.finite(best.distanceSquared)) throw "坡道距离超出数值范围";
		if (lineIntersects(start,end) || best.distanceSquared < 1e-20) {
			var depth = Math.POSITIVE_INFINITY, direction:Vector3D = null;
			// 中心线进入凸体时，按最小可分离面保守推出，避免产生不确定的零距离法线。
			for (plane in planes) {
				var amount = radius+half*Math.abs(plane.normal.y)-(plane.normal.dotProduct(center)+plane.constant);
				if (amount < depth) { depth = amount; direction = plane.normal; }
			}
			return {separation:-Math.max(0,depth),normal:direction.clone(),point:best.surface.clone(),surfaceNormal:direction.clone()};
		}
		var distance = Math.sqrt(best.distanceSquared), normal = best.line.subtract(best.surface); normal.scaleBy(1/distance);
		if (!Math3D.finite(distance)) throw "坡道距离超出数值范围";
		return {separation:distance-radius,normal:normal,point:best.surface.clone(),surfaceNormal:face.clone()};
	}
	override public function raycast(ray:Ray3D,maxDistance:Float):CollisionHit3D {
		refresh(); var near = 0., far = maxDistance, normal:Vector3D = null, inside:Vector3D = null, nearest = Math.NEGATIVE_INFINITY;
		for (plane in planes) {
			var distance = plane.normal.dotProduct(ray.origin)+plane.constant, denominator = plane.normal.dotProduct(ray.direction);
			if (distance > nearest) { nearest = distance; inside = plane.normal; }
			if (Math.abs(denominator) < 1e-12) { if (distance > 0) return null; continue; }
			var t = -distance/denominator;
			if (denominator < 0) { if (t > near) { near = t; normal = plane.normal; } } else far = Math.min(far,t);
			if (near > far) return null;
		}
		if (!Math3D.finite(near)) return null;
		return new CollisionHit3D(this,ray.at(near),normal == null ? inside : normal,near);
	}
	override public function dispose():Void { if (isDisposed) return; super.dispose(); triangles = []; planes = []; settings = []; bounds = null; cachedNode = null; }
}

private typedef RampTriangle3D = { var a:Vector3D; var b:Vector3D; var c:Vector3D; var normal:Vector3D; }
private typedef RampPlane3D = { var normal:Vector3D; var constant:Float; }
