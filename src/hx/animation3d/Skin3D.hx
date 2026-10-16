package hx.animation3d;

import hx.display.MeshObject;
import hx.geom.Matrix3D;
import hx.formats.gltf.GltfData.GltfPrimitiveData;
import hx.formats.gltf.GltfData.GltfSkinData;

/** 在模型局部空间计算关节矩阵；外层 Model3D 变换只由显示树应用一次。 */
class Skin3D {
	private var data:GltfSkinData;
	private var inverses:Array<Matrix3D>;
	private var palette:Array<Matrix3D>;
	private var bindings:Array<SkinBinding3D> = [];
	public function new(data:GltfSkinData) {
		this.data = data; inverses = [for (matrix in data.inverseBindMatrices) new Matrix3D(matrix)];
		palette = [for (_ in data.joints) new Matrix3D()];
	}
	/** 刚性单关节网格直接复用网格矩阵；其他网格使用实例独立的 CPU 顶点。 */
	public function bind(mesh:MeshObject, primitive:GltfPrimitiveData):Void { bindings.push(new SkinBinding3D(mesh, primitive)); }
	public function update(world:Array<Matrix3D>):Void {
		for (i in 0...palette.length) {
			var a = world[data.joints[i]].rawData, b = inverses[i].rawData, out = palette[i].rawData;
			for (column in 0...4) for (row in 0...4) {
				var value = 0.; for (k in 0...4) value += a[k*4+row] * b[column*4+k]; out[column*4+row] = value;
			}
		}
		for (binding in bindings) binding.update(palette);
	}
	public function dispose():Void { data = null; inverses = []; palette = []; bindings = []; }
}

private class SkinBinding3D {
	private var mesh:MeshObject;
	private var source:GltfPrimitiveData;
	private var rigidJoint:Int = -1;
	private var lastMatrix:Array<Float>;
	public function new(mesh:MeshObject, source:GltfPrimitiveData) {
		this.mesh = mesh; this.source = source;
		var candidate = -1, rigid = true;
		for (vertex in 0...Std.int(source.positions.length / 3)) {
			var influences = 0;
			for (slot in 0...4) {
				var i = vertex*4+slot, weight = source.weights[i];
				if (weight == 0) continue;
				influences++;
				if (weight != 1 || (candidate >= 0 && candidate != source.joints[i])) rigid = false;
				candidate = source.joints[i];
			}
			if (influences != 1) rigid = false;
		}
		if (rigid) rigidJoint = candidate;
	}
	public function update(palette:Array<Matrix3D>):Void {
		if (mesh.isDisposed || mesh.geometry == null) return;
		if (rigidJoint >= 0) {
			var matrix = palette[rigidJoint], changed = lastMatrix == null;
			if (!changed) for (i in 0...16) if (lastMatrix[i] != matrix.rawData[i]) { changed = true; break; }
			if (changed) { mesh.setLocalMatrix(matrix); lastMatrix = matrix.rawData.copy(); }
			return;
		}
		var output = mesh.geometry.positions, input = source.positions;
		for (vertex in 0...Std.int(input.length / 3)) {
			var offset = vertex*3, x = input[offset], y = input[offset+1], z = input[offset+2];
			var ox = 0., oy = 0., oz = 0.;
			for (slot in 0...4) {
				var i = vertex*4+slot, weight = source.weights[i]; if (weight == 0) continue;
				var m = palette[source.joints[i]].rawData;
				ox += (m[0]*x + m[4]*y + m[8]*z + m[12])*weight;
				oy += (m[1]*x + m[5]*y + m[9]*z + m[13])*weight;
				oz += (m[2]*x + m[6]*y + m[10]*z + m[14])*weight;
			}
			output[offset] = ox; output[offset+1] = oy; output[offset+2] = oz;
		}
		mesh.geometry.invalidate();
	}
}
