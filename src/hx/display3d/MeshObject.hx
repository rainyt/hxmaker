package hx.display3d;

import hx.events.Event;
import hx.geom.Bounds3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.render3d.Math3D;
import hx.render3d.ShadowMobility3D;
import hx.render3d.GeometryMobility3D;

/** 三维网格节点；几何和材质可共享，销毁节点仅释放引用。 */
class MeshObject extends Node3D {
	/** 导入蒙皮的只读绑定数据；后端仅协商 gpuEnabled，其他字段不得修改。 */
	public var skinBinding:hx.animation3d.Skin3D.SkinBinding3D;
	/** 引用的共享几何；更换时自动维护引用计数，不自动销毁旧几何。 */
	public var geometry(get, set):Geometry3D;

	/** 引用的共享材质；更换时自动维护引用计数，不自动销毁旧材质。 */
	public var material(get, set):Material3D;

	/** 是否参与三角形射线拾取，默认 true。 */
	public var pickable:Bool = true;

	/** 是否启用相机视锥裁剪，默认 true。 */
	public var frustumCulling:Bool = true;

	private var __renderOrder:Int = 0;

	/** 透明通道先按此值升序，再按深度排序；较大值后绘制。 */
	public var renderOrder(get, set):Int;

	private function get_renderOrder():Int {
		return __renderOrder;
	}

	private function set_renderOrder(value:Int):Int {
		if (__renderOrder != value) {
			__renderOrder = value;
			invalidate();
		}
		return value;
	}

	private var __castShadow:Bool = false;
	private var __receiveShadow:Bool = true;
	private var __shadowMobility:ShadowMobility3D = ShadowMobility3D.DYNAMIC;

	/** 阴影几何的更新策略，默认动态；静态对象被修改时仍会正确重建。 */
	public var shadowMobility(get, set):ShadowMobility3D;
	private function get_shadowMobility():ShadowMobility3D { return __shadowMobility; }
	private function set_shadowMobility(value:ShadowMobility3D):ShadowMobility3D {
		if (value != ShadowMobility3D.STATIC && value != ShadowMobility3D.DYNAMIC && value != ShadowMobility3D.AUTO) throw "无效的阴影更新策略";
		if (__shadowMobility != value) { __shadowMobility = value; invalidate(); }
		return value;
	}

	private var __geometryMobility:GeometryMobility3D = GeometryMobility3D.DYNAMIC;
	/** 主场景缓存策略，独立于阴影策略。 */
	public var geometryMobility(get, set):GeometryMobility3D;
	private function get_geometryMobility():GeometryMobility3D { return __geometryMobility; }
	private function set_geometryMobility(value:GeometryMobility3D):GeometryMobility3D {
		if (value != GeometryMobility3D.STATIC && value != GeometryMobility3D.DYNAMIC && value != GeometryMobility3D.AUTO) throw "无效的主场景几何策略";
		if (__geometryMobility != value) { __geometryMobility = value; invalidate(); }
		return value;
	}
	@:allow(hx.render3d.MobilityTracker3D)
	private var __autoStatic:Bool = false;
	/** AUTO 最近一次场景同步后的有效策略；脱离场景后按动态处理。 */
	public var effectiveGeometryMobility(get, never):GeometryMobility3D;
	private function get_effectiveGeometryMobility():GeometryMobility3D {
		return __geometryMobility == GeometryMobility3D.AUTO ? (scene != null && __autoStatic ? GeometryMobility3D.STATIC : GeometryMobility3D.DYNAMIC) : __geometryMobility;
	}
	public var effectiveShadowMobility(get, never):ShadowMobility3D;
	private function get_effectiveShadowMobility():ShadowMobility3D {
		return __shadowMobility == ShadowMobility3D.AUTO ? (scene != null && __autoStatic ? ShadowMobility3D.STATIC : ShadowMobility3D.DYNAMIC) : __shadowMobility;
	}

	/** 是否允许投射阴影，仍受材质透明模式与光照阴影设置约束。 */
	public var castShadow(get, set):Bool;

	/** 是否接收方向光阴影，仍需材质启用光照。 */
	public var receiveShadow(get, set):Bool;

	private function get_castShadow():Bool {
		return __castShadow;
	}

	private function set_castShadow(value:Bool):Bool {
		if (__castShadow != value) {
			__castShadow = value;
			invalidate();
		}
		return value;
	}

	private function get_receiveShadow():Bool {
		return __receiveShadow;
	}

	private function set_receiveShadow(value:Bool):Bool {
		if (__receiveShadow != value) {
			__receiveShadow = value;
			invalidate();
		}
		return value;
	}

	private var __geometry:Geometry3D;
	private var __material:Material3D;
	private var __vertices:Array<Float> = [];
	private var __geometryVersion:Int = -1;
	private var __worldVersion:Int = -1;
	private var __normals:Array<Float> = [];
	private var __normalGeometryVersion:Int = -1;
	private var __normalWorldVersion:Int = -1;
	private var __tangents:Array<Float> = [];
	private var __tangentGeometryVersion:Int = -1;
	private var __tangentWorldVersion:Int = -1;

	/** 创建并引用几何与材质；节点销毁时释放引用但不销毁共享资源。 */
	public function new(geometry:Geometry3D, material:Material3D) {
		super();
		this.geometry = geometry;
		this.material = material;
	}

	private function get_geometry():Geometry3D {
		return __geometry;
	}

	private function set_geometry(value:Geometry3D):Geometry3D {
		if (isDisposed)
			throw "模型已经销毁";
		if (value == __geometry)
			return value;
		if (value != null)
			value.retain();
		if (__geometry != null) {
			__geometry.removeEventListener(Event.CHANGE, onResourceChange);
			__geometry.release();
		}
		__geometry = value;
		__geometryVersion = -1;
		__normalGeometryVersion = -1;
		__tangentGeometryVersion = -1;
		if (value != null)
			value.addEventListener(Event.CHANGE, onResourceChange);
		invalidate();
		return value;
	}

	private function get_material():Material3D {
		return __material;
	}

	private function set_material(value:Material3D):Material3D {
		if (isDisposed)
			throw "模型已经销毁";
		if (value == __material)
			return value;
		if (value != null)
			value.retain();
		if (__material != null) {
			__material.removeEventListener(Event.CHANGE, onResourceChange);
			__material.release();
		}
		__material = value;
		if (value != null)
			value.addEventListener(Event.CHANGE, onResourceChange);
		invalidate();
		return value;
	}

	private function onResourceChange(event:Event):Void {
		invalidate();
	}

	/** 返回只供渲染器读取的缓存；调用方不得修改。 */
	public function getWorldVertices():Array<Float> {
		if (__geometry == null)
			return [];
		var matrix = getWorldMatrix();
		if (__geometryVersion != __geometry.version || __worldVersion != worldVersion) {
			__vertices = [];
			matrix.transformVectors(__geometry.positions, __vertices);
			__geometryVersion = __geometry.version;
			__worldVersion = worldVersion;
		}
		return __vertices;
	}

	/** 返回世界空间轴对齐包围盒，包含所属节点的变换。 */
	public function getWorldBounds():Bounds3D {
		return __geometry == null ? new Bounds3D() : __geometry.bounds.transformed(getWorldMatrix());
	}

	/** 世界法线与世界顶点分别缓存，无光照路径不生成或变换法线。 */
	public function getWorldNormals():Array<Float> {
		if (__geometry == null)
			return [];
		var matrix = getWorldMatrix();
		if (__normalGeometryVersion != __geometry.version || __normalWorldVersion != worldVersion) {
			var source = __geometry.getNormals();
			for (vertex in 0...Std.int(source.length / 3)) {
				var i = vertex * 3;
				Math3D.transformNormal(matrix.rawData, source[i], source[i + 1], source[i + 2], __normals, i);
			}
			__normals.resize(source.length);
			__normalGeometryVersion = __geometry.version;
			__normalWorldVersion = worldVersion;
		}
		return __normals;
	}

	/** 世界切线用线性矩阵变换，并修正非均匀缩放和镜像手性。 */
	public function getWorldTangents():Array<Float> {
		if (__geometry == null) return [];
		var matrix = getWorldMatrix();
		if (__tangentGeometryVersion != __geometry.version || __tangentWorldVersion != worldVersion) {
			var source = __geometry.getTangents(), normals = getWorldNormals();
			for (vertex in 0...Std.int(source.length / 4)) {
				var i = vertex * 4, n = vertex * 3;
				Math3D.transformTangent(matrix.rawData, source[i], source[i + 1], source[i + 2], source[i + 3],
					normals[n], normals[n + 1], normals[n + 2], __tangents, i);
			}
			__tangents.resize(source.length);
			__tangentGeometryVersion = __geometry.version; __tangentWorldVersion = worldVersion;
		}
		return __tangents;
	}

	/** 幂等解除几何材质的引用与监听，再销毁节点及子树。 */
	override public function dispose():Void {
		if (isDisposed)
			return;
		geometry = null;
		material = null;
		__vertices = [];
		__normals = [];
		__tangents = [];
		super.dispose();
		skinBinding = null;
	}
}
