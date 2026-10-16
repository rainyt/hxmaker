package hx.collision3d;

import hx.geom.Vector3D;

/** 线段到三角形的最近点，供封闭凸坡道的窄相位查询使用。 */
class TriangleDistance3D {
	private static function scaled(value:Vector3D,t:Float):Vector3D { return new Vector3D(value.x*t,value.y*t,value.z*t); }
	public static function pointTriangle(p:Vector3D,a:Vector3D,b:Vector3D,c:Vector3D):Vector3D {
		var ab = b.subtract(a), ac = c.subtract(a), ap = p.subtract(a), d1 = ab.dotProduct(ap), d2 = ac.dotProduct(ap);
		if (d1 <= 0 && d2 <= 0) return a.clone();
		var bp = p.subtract(b), d3 = ab.dotProduct(bp), d4 = ac.dotProduct(bp);
		if (d3 >= 0 && d4 <= d3) return b.clone();
		var vc = d1*d4-d3*d2;
		if (vc <= 0 && d1 >= 0 && d3 <= 0) return a.add(scaled(ab,d1/(d1-d3)));
		var cp = p.subtract(c), d5 = ab.dotProduct(cp), d6 = ac.dotProduct(cp);
		if (d6 >= 0 && d5 <= d6) return c.clone();
		var vb = d5*d2-d1*d6;
		if (vb <= 0 && d2 >= 0 && d6 <= 0) return a.add(scaled(ac,d2/(d2-d6)));
		var va = d3*d6-d5*d4;
		if (va <= 0 && d4-d3 >= 0 && d5-d6 >= 0) return b.add(scaled(c.subtract(b),(d4-d3)/((d4-d3)+(d5-d6))));
		var inverse = 1/(va+vb+vc); return a.add(scaled(ab,vb*inverse)).add(scaled(ac,vc*inverse));
	}
	private static function segmentPair(p:Vector3D,q:Vector3D,a:Vector3D,b:Vector3D):TrianglePair3D {
		var d1 = q.subtract(p), d2 = b.subtract(a), r = p.subtract(a);
		var aa = d1.dotProduct(d1), ee = d2.dotProduct(d2), f = d2.dotProduct(r), s = 0., t = 0.;
		if (aa <= 1e-20) t = ee <= 1e-20 ? 0 : CollisionMath3D.clamp(f/ee,0,1);
		else {
			var c = d1.dotProduct(r);
			if (ee <= 1e-20) s = CollisionMath3D.clamp(-c/aa,0,1);
			else {
				var bb = d1.dotProduct(d2), denominator = aa*ee-bb*bb;
				if (denominator > 1e-20) s = CollisionMath3D.clamp((bb*f-c*ee)/denominator,0,1);
				t = (bb*s+f)/ee;
				if (t < 0) { t = 0; s = CollisionMath3D.clamp(-c/aa,0,1); }
				else if (t > 1) { t = 1; s = CollisionMath3D.clamp((bb-c)/aa,0,1); }
			}
		}
		return pair(p.add(scaled(d1,s)),a.add(scaled(d2,t)));
	}
	private static function pair(line:Vector3D,surface:Vector3D):TrianglePair3D {
		var delta = line.subtract(surface); return {line:line,surface:surface,distanceSquared:delta.dotProduct(delta)};
	}
	public static function segmentTriangle(p:Vector3D,q:Vector3D,a:Vector3D,b:Vector3D,c:Vector3D):TrianglePair3D {
		var normal = b.subtract(a).crossProduct(c.subtract(a)), delta = q.subtract(p), denominator = normal.dotProduct(delta);
		if (Math.abs(denominator) > 1e-14) {
			var t = normal.dotProduct(a.subtract(p))/denominator;
			if (t >= 0 && t <= 1) {
				var intersection = p.add(scaled(delta,t)), closest = pointTriangle(intersection,a,b,c);
				var candidate = pair(intersection,closest); if (candidate.distanceSquared < 1e-20) return candidate;
			}
		}
		var best = pair(p,pointTriangle(p,a,b,c)), end = pair(q,pointTriangle(q,a,b,c));
		if (end.distanceSquared < best.distanceSquared) best = end;
		for (edge in [[a,b],[b,c],[c,a]]) {
			var candidate = segmentPair(p,q,edge[0],edge[1]); if (candidate.distanceSquared < best.distanceSquared) best = candidate;
		}
		return best;
	}
}

typedef TrianglePair3D = { var line:Vector3D; var surface:Vector3D; var distanceSquared:Float; }
