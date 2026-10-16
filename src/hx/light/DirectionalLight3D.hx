package hx.light;

import hx.display.Node3D;
import hx.geom.Vector3D;
import hx.geom.Bounds3D;
import hx.render3d.Math3D;

/** 方向表示光传播方向；加入 Scene3D.root 后可作为该场景的单方向光。 */
class DirectionalLight3D extends Node3D {
	public var color:Int = 0xffffff;
	public var intensity:Float = 1;
	public var shadowEnabled:Bool = false;
	public var shadowMapSize:Int = 1024;
	public var shadowBias:Float = 0.001;
	public var shadowSlopeBias:Float = 0.002;
	public var shadowPadding:Float = 0.1;
	/** 可选世界空间范围；为空时自动适配投射物与接收深度。 */
	public var shadowBounds:Bounds3D;
	private var __direction:Vector3D = new Vector3D(-1, -2, -1);
	public var direction(get, set):Vector3D;
	private function get_direction():Vector3D { return __direction.clone(); }
	private function set_direction(value:Vector3D):Vector3D {
		if (value == null || !Math3D.finite(value.x) || !Math3D.finite(value.y) || !Math3D.finite(value.z)) throw "方向光方向无效";
		var copy = value.clone(); if (copy.normalize() < 1e-10) throw "方向光方向不能为零";
		__direction = copy; invalidate(); return value;
	}
	public function new(color:Int = 0xffffff, intensity:Float = 1) { super(); this.color = color; this.intensity = intensity; }
	public function getWorldDirection():Vector3D {
		var m = getWorldMatrix().rawData, d = __direction;
		var result = new Vector3D(m[0]*d.x+m[4]*d.y+m[8]*d.z, m[1]*d.x+m[5]*d.y+m[9]*d.z, m[2]*d.x+m[6]*d.y+m[10]*d.z);
		if (result.normalize() < 1e-10) throw "方向光变换使方向退化"; return result;
	}
	/** 同时用于参数校验和静态场景失效检测，不读取 GPU 状态。 */
	public function settingsKey():String {
		for (value in [intensity, shadowBias, shadowSlopeBias, shadowPadding]) if (!Math3D.finite(value) || value < 0) throw "方向光强度或阴影参数无效";
		if (shadowMapSize < 16 || shadowMapSize > 8192 || (shadowMapSize & (shadowMapSize - 1)) != 0) throw "阴影尺寸必须是 16～8192 的二次幂";
		if (shadowBounds != null) {
			if (shadowBounds.isEmpty()) throw "阴影范围不能为空";
			for (value in [shadowBounds.min.x,shadowBounds.min.y,shadowBounds.min.z,shadowBounds.max.x,shadowBounds.max.y,shadowBounds.max.z])
				if (!Math3D.finite(value)) throw "阴影范围必须是有限值";
		}
		var d = getWorldDirection();
		var values:Array<Dynamic> = [color, intensity, isWorldVisible(), d.x,d.y,d.z, shadowEnabled,shadowMapSize,shadowBias,shadowSlopeBias,shadowPadding,
			shadowBounds == null ? "自动" : [shadowBounds.min.x,shadowBounds.min.y,shadowBounds.min.z,shadowBounds.max.x,shadowBounds.max.y,shadowBounds.max.z].join(",")];
		return values.join(":");
	}
}
