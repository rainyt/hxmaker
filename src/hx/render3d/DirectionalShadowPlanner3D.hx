package hx.render3d;

import hx.display3d.Camera3D;
import hx.geom.Bounds3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.light.DirectionalLight3D;

/** 与 GPU 解耦的有状态取景规划：自动有效距离、紧凑区域识别及延迟收缩。 */
class DirectionalShadowPlanner3D {
	private var lastLight:DirectionalLight3D;
	private var directionKey:String;
	private var stableDistance:Float = 0;
	private var stableSize:Float = 0;
	private var distanceShrinkAt:Float = -1;
	private var sizeShrinkAt:Float = -1;
	private var compact:Bool = false;
	public function new() {}

	public function reset():Void {
		lastLight = null; directionKey = null; stableDistance = stableSize = 0;
		distanceShrinkAt = sizeShrinkAt = -1; compact = false;
	}

	public function plan(camera:Camera3D, aspect:Float, light:DirectionalLight3D,
		casters:Array<Bounds3D>, receivers:Array<Bounds3D>, now:Float):DirectionalShadowPlan3D {
		var settings = new DirectionalShadowSettings3D(light), result = new DirectionalShadowPlan3D(settings);
		var direction = light.getWorldDirection(), view = DirectionalShadowFit3D.lightView(direction);
		var key = [direction.x, direction.y, direction.z, light.shadowQuality * 1.].join(":");
		if (lastLight != light || directionKey != key) { reset(); lastLight = light; directionKey = key; }
		result.lightView = view; result.casters = casters;
		if (light.shadowBounds != null) {
			result.mode = "手动世界范围"; result.lightBounds = light.shadowBounds.transformed(view); return result;
		}
		var near = camera.near, end = settings.distance == 0 ? camera.far : Math.min(camera.far, Math.max(near + 0.001, settings.distance));
		var cameraView = camera.getViewMatrix(), projection = camera.getViewProjection(aspect);
		var visible = [for (box in casters) if (box.inFrustum(projection)) box];
		var visibleReceivers = [for (box in receivers) if (box.inFrustum(projection)) box];
		if (settings.automaticDistance && visible.length == 0 && stableDistance > near) end = Math.min(camera.far, stableDistance);
		if (settings.automaticDistance && visible.length > 0) {
			var focus = union([for (box in visible) box.transformed(view)]);
			var inverse = view.clone(); inverse.invert();
			var maximumDepth = near;
			for (box in visible) maximumDepth = Math.max(maximumDepth, farDepth(box, cameraView));
			// 将接收物裁剪到投影物的光空间列；大地面不能把有效距离拉到自身远端。
			for (box in visibleReceivers) {
				var clipped = clipReceiver(box, view, focus);
				if (!clipped.isEmpty()) maximumDepth = Math.max(maximumDepth, farDepth(clipped.transformed(inverse), cameraView));
			}
			var wanted = quantize(Math.max(near * 1.01, maximumDepth * 1.15));
			end = Math.min(camera.far, stabilize(wanted, now, false));
		}
		end = Math.max(near + Math.max(1e-9, near * 1e-6), Math.min(camera.far, end));
		var minimum = settings.adaptive ? Math.max(1e-9, end * 1e-6) : 0.1;
		var probe = new DirectionalShadowFit3D(camera, aspect, end, direction, 0, minimum);
		var relevant = [for (box in casters) if (probe.affects(box, settings.padding)) box];
		result.casters = relevant;
		if (settings.compactAllowed && relevant.length > 0) {
			var region = union([for (box in relevant) box.transformed(view)]);
			var span = Math.max(region.max.x-region.min.x, region.max.y-region.min.y);
			var available = probe.bounds.max.x-probe.bounds.min.x;
			// 进入和退出使用不同阈值，避免临界镜头反复切换级联布局。
			var useCompact = span < available * (compact ? 0.75 : 0.5);
			if (useCompact) {
				compact = true;
				for (box in visibleReceivers) {
					var receiver = clipReceiver(box, view, region);
					if (!receiver.isEmpty()) { region.min.z = Math.min(region.min.z, receiver.min.z); region.max.z = Math.max(region.max.z, receiver.max.z); }
				}
				var size = stabilize(quantize(Math.max(1e-9, span)), now, true);
				var cx = (region.min.x+region.max.x)*0.5, cy = (region.min.y+region.max.y)*0.5;
				region.min.x = cx-size*0.5; region.max.x = cx+size*0.5;
				region.min.y = cy-size*0.5; region.max.y = cy+size*0.5;
				result.mode = "自动紧凑范围"; result.lightBounds = region; return result;
			}
		}
		compact = false; stableSize = 0; sizeShrinkAt = -1;
		result.count = settings.cascades; result.distance = end;
		result.mode = settings.adaptive ? "自动相机范围" : "传统相机范围";
		var split = result.count == 2 ? DirectionalShadowFit3D.splitDistance(near, end, settings.split) : end;
		var blendStart = result.count == 2 ? split-(split-near)*settings.blend : end;
		result.fits = [new DirectionalShadowFit3D(camera, aspect, split, direction, 0, minimum)];
		if (result.count == 2) result.fits.push(new DirectionalShadowFit3D(camera, aspect, end, direction, blendStart, minimum));
		result.singleFit = probe;
		result.params = [split, blendStart, end-(end-near)*settings.fade, end];
		var v = cameraView.rawData; result.cameraDepth = [-v[2], -v[6], -v[10], -v[14]];
		return result;
	}

	/** 尺度按四分之一个倍频程量化；需要扩张时立即扩张，缩小持续稳定后再应用。 */
	private function stabilize(wanted:Float, now:Float, size:Bool):Float {
		var previous = size ? stableSize : stableDistance, since = size ? sizeShrinkAt : distanceShrinkAt;
		if (previous <= 0 || wanted > previous) { previous = wanted; since = -1; }
		else if (wanted < previous * 0.8) {
			if (since < 0) since = now;
			if (now-since >= 0.75) { previous = wanted; since = -1; }
		} else since = -1;
		if (size) { stableSize = previous; sizeShrinkAt = since; }
		else { stableDistance = previous; distanceShrinkAt = since; }
		return previous;
	}
	private static function quantize(value:Float):Float { return Math.pow(2, Math.ceil(Math.log(value)/Math.log(2)*4)/4); }
	private static function union(boxes:Array<Bounds3D>):Bounds3D {
		var result = new Bounds3D();
		for (box in boxes) if (!box.isEmpty()) { result.include(box.min.x,box.min.y,box.min.z); result.include(box.max.x,box.max.y,box.max.z); }
		return result;
	}
	private static function farDepth(box:Bounds3D, view:Matrix3D):Float { return -box.transformed(view).min.z; }

	/** 对接收包围盒的六个面做列裁剪，保留平面与薄片，不把整个大地面的深度并入。 */
	private static function clipReceiver(box:Bounds3D, view:Matrix3D, column:Bounds3D):Bounds3D {
		var corners = [for (i in 0...8) view.transformVector(new Vector3D((i&1)==0?box.min.x:box.max.x,
			(i&2)==0?box.min.y:box.max.y, (i&4)==0?box.min.z:box.max.z))];
		var result = new Bounds3D();
		for (face in [[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6],[0,1,3,2],[4,6,7,5]]) {
			var polygon = [for (index in face) corners[index]];
			for (plane in 0...4) {
				if (polygon.length == 0) break;
				var next:Array<Vector3D> = [], previous = polygon[polygon.length-1];
				var previousDistance = planeDistance(previous, column, plane);
				for (point in polygon) {
					var distance = planeDistance(point, column, plane);
					if ((distance >= 0) != (previousDistance >= 0)) {
						var t = previousDistance/(previousDistance-distance);
						next.push(new Vector3D(previous.x+(point.x-previous.x)*t,previous.y+(point.y-previous.y)*t,previous.z+(point.z-previous.z)*t));
					}
					if (distance >= 0) next.push(point);
					previous = point; previousDistance = distance;
				}
				polygon = next;
			}
			for (point in polygon) result.include(point.x,point.y,point.z);
		}
		return result;
	}
	private static function planeDistance(point:Vector3D, box:Bounds3D, plane:Int):Float {
		return switch (plane) { case 0: point.x-box.min.x; case 1: box.max.x-point.x; case 2: point.y-box.min.y; default: box.max.y-point.y; };
	}
}
