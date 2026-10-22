package hx.light;

import hx.display3d.Node3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 场景灯光公共节点；方向表示光传播方向，点光忽略方向。 */
class Light3D extends Node3D {
	public var color:Int = 0xffffff;
	/** 非负有限强度；关闭灯光可设置 visible=false。 */
	public var intensity:Float = 1;

	public function new(color:Int = 0xffffff, intensity:Float = 1) {
		super();
		this.color = color;
		this.intensity = intensity;
	}

	private var __direction:Vector3D = new Vector3D(-1, -2, -1);

	/** 局部光传播方向；设置时复制并归一化，读取返回副本。 */
	public var direction(get, set):Vector3D;

	private function get_direction():Vector3D {
		return __direction.clone();
	}

	private function set_direction(value:Vector3D):Vector3D {
		if (value == null || !Math3D.finite(value.x) || !Math3D.finite(value.y) || !Math3D.finite(value.z))
			throw "灯光方向无效";
		var copy = value.clone();
		if (copy.normalize() < 1e-10)
			throw "灯光方向不能为零";
		__direction = copy;
		invalidate();
		return value;
	}

	/** 返回应用节点世界变换后归一化的光传播方向。 */
	public function getWorldDirection():Vector3D {
		var m = getWorldMatrix().rawData, d = __direction;
		var result = new Vector3D(m[0] * d.x + m[4] * d.y + m[8] * d.z, m[1] * d.x + m[5] * d.y + m[9] * d.z, m[2] * d.x + m[6] * d.y + m[10] * d.z);
		if (result.normalize() < 1e-10)
			throw "灯光变换使方向退化";
		return result;
	}

	/** 校验参数并记录世界变换，供静态场景检测属性变化。 */
	public function settingsKey():String {
		if (!Math3D.finite(intensity) || intensity < 0) throw "灯光强度必须为非负有限值";
		var d = getWorldDirection(), m = getWorldMatrix().rawData;
		return Type.getClassName(Type.getClass(this)) + ":" + [color * 1., intensity, isWorldVisible() ? 1. : 0., m[12], m[13], m[14], d.x, d.y, d.z].join(":");
	}
}
