package hx.animation3d;

import hx.display3d.MeshObject;
import hx.geom.Matrix3D;
import hx.render3d.Math3D;
import hx.formats.gltf.GltfData.GltfPrimitiveData;
import hx.formats.gltf.GltfData.GltfSkinData;

/** 在模型局部空间计算关节矩阵；外层 Model3D 变换只由显示树应用一次。 */
class Skin3D {
	private var data:GltfSkinData;
	private var inverses:Array<Matrix3D>;
	private var palette:Array<Matrix3D>;
	private var bindings:Array<SkinBinding3D> = [];

	/** 借用导入蒙皮数据并创建实例独立的关节矩阵缓冲。 */
	public function new(data:GltfSkinData) {
		this.data = data;
		inverses = [for (matrix in data.inverseBindMatrices) new Matrix3D(matrix)];
		palette = [for (_ in data.joints) new Matrix3D()];
	}

	/** 刚性单关节网格直接复用网格矩阵；其他网格使用实例独立的 CPU 顶点。 */
	public function bind(mesh:MeshObject, primitive:GltfPrimitiveData):Void {
		bindings.push(new SkinBinding3D(mesh, primitive));
	}

	/** 根据模型局部空间节点矩阵更新蒙皮；每业务帧在最终姿态应用后调用一次。 */
	public function update(world:Array<Matrix3D>):Void {
		for (i in 0...palette.length) {
			var a = world[data.joints[i]].rawData,
				b = inverses[i].rawData,
				out = palette[i].rawData;
			for (column in 0...4)
				for (row in 0...4) {
					var value = 0.;
					for (k in 0...4)
						value += a[k * 4 + row] * b[column * 4 + k];
					out[column * 4 + row] = value;
				}
		}
		for (binding in bindings)
			binding.update(palette);
	}

	/** 清空蒙皮缓冲和借用引用，不销毁绑定的网格。 */
	public function dispose():Void {
		data = null;
		inverses = [];
		palette = [];
		bindings = [];
	}
}

private class SkinBinding3D {
	private var mesh:MeshObject;
	private var source:GltfPrimitiveData;
	private var rigidJoint:Int = -1;
	private var lastMatrix:Array<Float>;
	private var restNormals:Array<Float>;
	private var blended:Array<Float> = [for (_ in 0...16) 0.];

	/** 借用网格及源图元，选择刚性关节或实例 CPU 蒙皮路径。 */
	public function new(mesh:MeshObject, source:GltfPrimitiveData) {
		this.mesh = mesh;
		this.source = source;
		var candidate = -1, rigid = true;
		for (vertex in 0...Std.int(source.positions.length / 3)) {
			var influences = 0;
			for (slot in 0...4) {
				var i = vertex * 4 + slot, weight = source.weights[i];
				if (weight == 0)
					continue;
				influences++;
				if (weight != 1 || (candidate >= 0 && candidate != source.joints[i]))
					rigid = false;
				candidate = source.joints[i];
			}
			if (influences != 1)
				rigid = false;
		}
		if (rigid)
			rigidJoint = candidate;
		else {
			restNormals = mesh.geometry.getNormals().copy();
			mesh.geometry.setNormals(restNormals);
		}
	}

	/** 使用当前关节矩阵调色板更新绑定网格的实例顶点或刚性变换。 */
	public function update(palette:Array<Matrix3D>):Void {
		if (mesh.isDisposed || mesh.geometry == null)
			return;
		if (rigidJoint >= 0) {
			var matrix = palette[rigidJoint], changed = lastMatrix == null;
			if (!changed)
				for (i in 0...16)
					if (lastMatrix[i] != matrix.rawData[i]) {
						changed = true;
						break;
					}
			if (changed) {
				mesh.setLocalMatrix(matrix);
				lastMatrix = matrix.rawData.copy();
			}
			return;
		}
		var output = mesh.geometry.positions, input = source.positions;
		for (vertex in 0...Std.int(input.length / 3)) {
			var offset = vertex * 3,
				x = input[offset],
				y = input[offset + 1],
				z = input[offset + 2];
			var ox = 0., oy = 0., oz = 0.;
			for (i in 0...16)
				blended[i] = 0;
			for (slot in 0...4) {
				var i = vertex * 4 + slot, weight = source.weights[i];
				if (weight == 0)
					continue;
				var m = palette[source.joints[i]].rawData;
				for (column in 0...3)
					for (row in 0...3)
						blended[column * 4 + row] += m[column * 4 + row] * weight;
				ox += (m[0] * x + m[4] * y + m[8] * z + m[12]) * weight;
				oy += (m[1] * x + m[5] * y + m[9] * z + m[13]) * weight;
				oz += (m[2] * x + m[6] * y + m[10] * z + m[14]) * weight;
			}
			output[offset] = ox;
			output[offset + 1] = oy;
			output[offset + 2] = oz;
			Math3D.transformNormal(blended, restNormals[offset], restNormals[offset + 1], restNormals[offset + 2], mesh.geometry.normals, offset);
		}
		mesh.geometry.invalidate();
	}
}
