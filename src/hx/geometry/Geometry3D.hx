package hx.geometry;

import hx.display.EventDispatcher;
import hx.events.Event;
import hx.geom.Bounds3D;
import hx.render3d.Math3D;
import hx.model.ModelAssetData.ModelPrimitiveData;
import hx.model.ModelGeometryTools;

/** 共享 CPU 网格数据。直接修改数组后必须调用 invalidate()。 */
class Geometry3D extends EventDispatcher {
	/** 顶点局部位置数组，每个顶点连续存储 x/y/z；直接修改后需 invalidate。 */
	public var positions(default, null):Array<Float>;

	/** 顶点 UV 数组，每个顶点连续存储 u/v；直接修改后需 invalidate。 */
	public var uvs(default, null):Array<Float>;

	/** 三角形顶点索引数组，每三个索引定义一个三角形。 */
	public var indices(default, null):Array<Int>;

	/** 顶点局部法线数组；未提供时由 getNormals 按需生成。 */
	public var normals(default, null):Array<Float>;

	/** 可选逐顶点 RGBA，范围 0 至 1；与材质颜色相乘，空数组表示白色。 */
	public var colors(default, null):Array<Float> = [];

	private var generatedNormals:Bool = false;

	/** 最近一次 invalidate 计算的局部 AABB，应视为只读。 */
	public var bounds(default, null):Bounds3D;

	/** 数据变更版本，用于使渲染缓存失效。 */
	public var version(default, null):Int = 0;

	/** 当前网格持有的引用数量；释放到零后仍需显式销毁资源。 */
	public var referenceCount(default, null):Int = 0;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 复制顶点、UV、三角形索引及可选法线，校验数据并计算初始包围盒。 */
	public function new(positions:Array<Float>, uvs:Array<Float>, indices:Array<Int>, normals:Array<Float> = null) {
		if (positions == null || uvs == null || indices == null)
			throw "三维几何数据不能为空";
		this.positions = positions.copy();
		this.uvs = uvs.copy();
		this.indices = indices.copy();
		this.normals = normals == null || normals.length == 0 ? null : normals.copy();
		invalidate();
	}

	/** 仅供模型实例使用：输入已经由资产构建器校验，复制实例缓冲并直接采用预计算边界。 */
	@:allow(hx.display3d.Model3D)
	private static function fromModelPrimitive(primitive:ModelPrimitiveData, skinned:Bool):Geometry3D {
		var geometry = new Geometry3D([], [], []);
		geometry.positions = primitive.positions.copy();
		geometry.uvs = primitive.uvs.copy();
		geometry.indices = primitive.indices.copy();
		geometry.normals = primitive.normals.copy();
		// 蒙皮每帧更新法线；静态自动法线仍需在业务修改顶点后失效。
		geometry.generatedNormals = primitive.generatedNormals && (!skinned || primitive.rigidJoint >= 0);
		if (primitive.bounds.length == 6) {
			geometry.bounds.min.setTo(primitive.bounds[0], primitive.bounds[1], primitive.bounds[2]);
			geometry.bounds.max.setTo(primitive.bounds[3], primitive.bounds[4], primitive.bounds[5]);
		}
		return geometry;
	}

	/** 校验数组、重算局部包围盒并递增版本；自动生成的法线同时失效。 */
	public function invalidate():Void {
		if (isDisposed)
			throw "几何数据已经销毁";
		if (positions.length % 3 != 0 || uvs.length != Std.int(positions.length / 3) * 2 || indices.length % 3 != 0)
			throw "三维几何的位置、UV 或三角形索引长度无效";
		if (colors.length != 0 && colors.length != Std.int(positions.length / 3) * 4)
			throw "三维顶点颜色数量与位置不一致";
		for (value in colors)
			if (!Math3D.finite(value) || value < 0 || value > 1)
				throw "三维顶点颜色必须介于 0 和 1";
		for (value in positions)
			if (!Math3D.finite(value))
				throw "三维顶点包含无效数值";
		for (value in uvs)
			if (!Math3D.finite(value))
				throw "三维 UV 包含无效数值";
		for (index in indices)
			if (index < 0 || index >= Std.int(positions.length / 3))
				throw "三维索引超出顶点范围";
		if (generatedNormals)
			normals = null;
		if (normals != null) {
			if (normals.length != positions.length)
				throw "三维法线数量与位置不一致";
			for (value in normals)
				if (!Math3D.finite(value))
					throw "三维法线包含无效数值";
		}
		bounds = new Bounds3D();
		for (i in 0...Std.int(positions.length / 3))
			bounds.include(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2]);
		version++;
		dispatchEvent(new Event(Event.CHANGE));
	}

	/** 缺失法线时按三角形面积累加，生成共享顶点的平滑法线。 */
	public function getNormals():Array<Float> {
		if (isDisposed)
			throw "几何数据已经销毁";
		if (normals != null)
			return normals;
		normals = ModelGeometryTools.generateNormals(positions, indices);
		generatedNormals = true;
		return normals;
	}

	/** 将法线转为显式数据；之后修改位置时由调用方同步维护法线。 */
	public function setNormals(values:Array<Float>):Void {
		if (values == null || values.length != positions.length)
			throw "三维法线数量与位置不一致";
		for (value in values)
			if (!Math3D.finite(value))
				throw "三维法线包含无效数值";
		normals = values.copy();
		generatedNormals = false;
		invalidate();
	}

	/** 增加网格引用；已销毁资源不能再次引用。 */
	public function retain():Void {
		if (isDisposed)
			throw "几何数据已经销毁";
		referenceCount++;
	}

	/** 减少网格引用，计数不会小于零；不自动销毁资源。 */
	public function release():Void {
		if (referenceCount > 0)
			referenceCount--;
	}

	/** 无网格引用时幂等清空 CPU 数据与监听；仍被引用时抛异常。 */
	public function dispose():Void {
		if (referenceCount != 0)
			throw "仍有模型使用此几何数据";
		if (isDisposed)
			return;
		isDisposed = true;
		positions = [];
		colors = [];
		uvs = [];
		indices = [];
		normals = [];
		removeEventListeners();
	}
}
