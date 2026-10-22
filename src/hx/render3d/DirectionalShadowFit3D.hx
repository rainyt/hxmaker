package hx.render3d;

import hx.display3d.Camera3D;
import hx.geom.Bounds3D;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;

/** 相机局部的方向光阴影取景，不依赖 GPU；投影物不能扩大取景的 XY 范围。 */
class DirectionalShadowFit3D {
	public var view(default, null):Matrix3D;
	public var bounds(default, null):Bounds3D;
	public var depthRange(default, null):Float = 1;
	private var minimumExtent:Float;

	public function new(camera:Camera3D, aspect:Float, distance:Float, direction:Vector3D, nearDistance:Float = 0, minimumExtent:Float = 0.1) {
		this.minimumExtent = minimumExtent;
		if (camera == null || !Math3D.finite(distance) || distance <= 0 || !Math3D.finite(nearDistance) || nearDistance < 0
			|| !Math3D.finite(minimumExtent) || minimumExtent <= 0)
			throw "自动阴影相机或距离无效";
		camera.getProjectionMatrix(aspect);
		view = lightView(direction);
		bounds = new Bounds3D();
		var near = Math.max(camera.near, nearDistance);
		var far = Math.min(camera.far, Math.max(near + 0.001, distance));
		if (far <= near) throw "阴影级联的远距离必须大于近距离";
		var tangent = Math.tan(camera.fieldOfView * Math.PI / 360);
		var slopeSquared = tangent * tangent * (1 + aspect * aspect);
		// 用与相机旋转无关的包围球确定 XY 尺寸，避免旋转时投影持续缩放。
		var centerDepth = Math.min(far, (near + far) * (1 + slopeSquared) * 0.5);
		var world = camera.getWorldMatrix();
		var center = world.transformVector(new Vector3D(0, 0, -centerDepth));
		var lightCenter = view.transformVector(center), radius = 0.;
		for (depth in [near, far]) {
			var halfHeight = depth * tangent, halfWidth = halfHeight * aspect;
			for (i in 0...4) {
				var p = world.transformVector(new Vector3D((i & 1) == 0 ? -halfWidth : halfWidth,
					(i & 2) == 0 ? -halfHeight : halfHeight, -depth));
				radius = Math.max(radius, p.subtract(center).length);
				var lightPoint = view.transformVector(p);
				bounds.include(lightPoint.x, lightPoint.y, lightPoint.z);
			}
		}
		// 按相对尺度量化半径，吸收浮点误差，不把微型场景强行放大到固定世界单位。
		var step = Math.pow(2, Math.ceil(Math.log(Math.max(radius, 1e-12)) / Math.log(2))) / 1024;
		radius = Math.ceil(radius / step) * step;
		bounds.min.x = lightCenter.x - radius; bounds.max.x = lightCenter.x + radius;
		bounds.min.y = lightCenter.y - radius; bounds.max.y = lightCenter.y + radius;
	}

	/** 可选显式深度占比；省略时混合均匀与对数切分，优先分配近景采样。 */
	public static function splitDistance(near:Float, far:Float, ratio:Null<Float> = null):Float {
		if (!Math3D.finite(near) || !Math3D.finite(far) || near <= 0 || far <= near) throw "级联切分距离无效";
		if (ratio != null) {
			if (!Math3D.finite(ratio) || ratio <= 0 || ratio >= 1) throw "近级联深度占比必须大于 0 且小于 1";
			return near + (far - near) * ratio;
		}
		return (Math.sqrt(near * far) + (near + far) * 0.5) * 0.5;
	}

	/** 光空间的 Z 朝向光源，镜头外的上游投影物仍能影响范围内的接收物。 */
	public function affects(worldBounds:Bounds3D, padding:Float = 0):Bool {
		if (worldBounds.isEmpty()) return false;
		var box = worldBounds.transformed(view);
		var px = Math.max(minimumExtent, bounds.max.x - bounds.min.x) * padding;
		var py = Math.max(minimumExtent, bounds.max.y - bounds.min.y) * padding;
		return box.max.x >= bounds.min.x - px && box.min.x <= bounds.max.x + px
			&& box.max.y >= bounds.min.y - py && box.min.y <= bounds.max.y + py && box.max.z >= bounds.min.z;
	}

	/** XY 只取相机覆盖区；深度向光源延伸，保留镜头外投影物且不降低 XY 密度。 */
	public function projection(casters:Array<Bounds3D>, padding:Float, size:Int):Matrix3D {
		if (!Math3D.finite(padding) || padding < 0 || size <= 0) throw "阴影留边或分辨率无效";
		var maximumZ = bounds.max.z;
		for (box in casters) if (affects(box, padding)) maximumZ = Math.max(maximumZ, box.transformed(view).max.z);
		var margin = Math.max(minimumExtent, (maximumZ - bounds.min.z) * padding);
		depthRange = maximumZ - bounds.min.z + margin * 2;
		return projectionFor(view, bounds.min.x, bounds.max.x, bounds.min.y, bounds.max.y, bounds.min.z, maximumZ, padding, size, minimumExtent);
	}

	/** 统一的光空间基，避免自动取景与手动范围采用不同的光向约定。 */
	public static function lightView(direction:Vector3D):Matrix3D {
		if (direction == null || !Math3D.finite(direction.x) || !Math3D.finite(direction.y) || !Math3D.finite(direction.z))
			throw "阴影光源方向无效";
		var z = new Vector3D(-direction.x, -direction.y, -direction.z);
		if (z.normalize() < 1e-10) throw "阴影光源方向不能为零";
		var up = Math.abs(z.y) > 0.95 ? new Vector3D(0, 0, 1) : new Vector3D(0, 1, 0);
		var x = up.crossProduct(z); x.normalize(); var y = z.crossProduct(x);
		return new Matrix3D([x.x,y.x,z.x,0., x.y,y.y,z.y,0., x.z,y.z,z.z,0., 0.,0.,0.,1.]);
	}

	/** 对齐阴影纹素，并预留半个纹素，避免中心取整后裁掉原覆盖边缘。 */
	public static function projectionFor(view:Matrix3D, minX:Float, maxX:Float, minY:Float, maxY:Float,
		minZ:Float, maxZ:Float, padding:Float, size:Int, minimumExtent:Float = 0.1):Matrix3D {
		var width = Math.max(minimumExtent, maxX - minX) * (1 + padding * 2);
		var height = Math.max(minimumExtent, maxY - minY) * (1 + padding * 2);
		// 尺寸至少为 2；调用方的阴影贴图校验会进一步限制到 16～8192。
		var resolution = Math.max(2, size);
		width *= resolution / (resolution - 1); height *= resolution / (resolution - 1);
		var cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
		cx = Math.floor(cx / (width / resolution) + 0.5) * (width / resolution);
		cy = Math.floor(cy / (height / resolution) + 0.5) * (height / resolution);
		var margin = Math.max(minimumExtent, (maxZ - minZ) * padding);
		return Math3D.multiply(Math3D.orthographic(cx-width/2, cx+width/2, cy-height/2, cy+height/2, -maxZ-margin, -minZ+margin), view);
	}
}
