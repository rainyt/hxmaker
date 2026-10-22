package hx.render3d;

import hx.geom.Bounds3D;
import hx.geom.Matrix3D;

/** 核心层生成的阴影取景计划；后端只负责能力裁剪、资源分配与逐级绘制。 */
class DirectionalShadowPlan3D {
	public var mode:String = "相机级联";
	public var count:Int = 1;
	public var distance:Float = 0;
	public var fits:Array<DirectionalShadowFit3D> = [];
	public var singleFit:DirectionalShadowFit3D;
	public var lightBounds:Bounds3D;
	public var lightView:Matrix3D;
	public var casters:Array<Bounds3D> = [];
	public var params:Array<Float> = [0., 0., 0., 0.];
	public var cameraDepth:Array<Float> = [0., 0., -1., 0.];
	public var settings:DirectionalShadowSettings3D;
	public function new(settings:DirectionalShadowSettings3D) { this.settings = settings; }

	/** 分配降级为单级时重新生成完整覆盖投影，不能直接保留近级联。 */
	public function projections(size:Int, actualCount:Int):Array<Matrix3D> {
		if (lightBounds != null) {
			var b = lightBounds;
			return [DirectionalShadowFit3D.projectionFor(lightView, b.min.x, b.max.x, b.min.y, b.max.y,
				b.min.z, b.max.z, settings.padding, size, settings.adaptive ? Math.max(1e-9, (b.max.x-b.min.x)*1e-6) : 0.1)];
		}
		var active = actualCount == 1 && fits.length > 1 ? [singleFit] : fits;
		return [for (fit in active) fit.projection(casters, settings.padding, size)];
	}
}
