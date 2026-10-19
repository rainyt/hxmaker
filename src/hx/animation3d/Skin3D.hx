package hx.animation3d;

import hx.display3d.MeshObject;
import hx.geom.Matrix3D;
import hx.render3d.Math3D;
import hx.model.ModelAssetData.ModelPrimitiveData;
import hx.model.ModelSourceData.ModelSkinData;
import hx.model.ModelGeometryTools;

/** 在模型局部空间计算关节矩阵；外层 Model3D 变换只由显示树应用一次。 */
class Skin3D {
	private var data:ModelSkinData;
	private var inverses:Array<Matrix3D>;
	private var palette:Array<Matrix3D>;
	private var bindings:Array<SkinBinding3D> = [];

	/** 借用导入蒙皮数据并创建实例独立的关节矩阵缓冲。 */
	public function new(data:ModelSkinData) {
		this.data = data;
		inverses = [for (matrix in data.inverseBindMatrices) new Matrix3D(matrix)];
		palette = [for (_ in data.joints) new Matrix3D()];
	}

	/** 刚性单关节网格直接复用网格矩阵；其他网格使用实例独立的 CPU 顶点。 */
	public function bind(mesh:MeshObject, primitive:ModelPrimitiveData):Void {
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
	private var source:ModelPrimitiveData;
	private var rigidJoint:Int = -1;
	private var lastMatrix:Array<Float>;
	private var restNormals:Array<Float>;
	private var restTangents:Array<Float>;
	private var blended:Array<Float> = [for (_ in 0...16) 0.];

	/** 借用网格及源图元，选择刚性关节或实例 CPU 蒙皮路径。 */
	public function new(mesh:MeshObject, source:ModelPrimitiveData) {
		this.mesh = mesh;
		this.source = source;
		rigidJoint = source.rigidJoint;
		// 原始法线属于只读资产，输出法线由实例几何独立持有。
		if (rigidJoint < 0)
			restNormals = source.normals;
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
		var updateTangents = (mesh.material != null && mesh.material.lightingEnabled && (mesh.material.pbrMapMask & 2) != 0)
			|| mesh.geometry.tangents != null;
		if (updateTangents && restTangents == null) {
			restTangents = source.tangents != null && source.tangents.length > 0 ? source.tangents
				: ModelGeometryTools.generateTangents(source.positions, restNormals, source.uvs, source.indices);
			mesh.geometry.setTangents(restTangents);
		}
		if (updateTangents && mesh.geometry.tangents == null) mesh.geometry.setTangents(restTangents);
		var geometry=mesh.geometry,output=geometry.positions,input=source.positions;
		var normals=geometry.normals,tangents=geometry.tangents;
		var minX=Math.POSITIVE_INFINITY,minY=minX,minZ=minX,maxX=Math.NEGATIVE_INFINITY,maxY=maxX,maxZ=maxX;
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
			// 与旧校验保持有限位置约束，在写入时顺便计算包围盒。
			if(!(ox>Math.NEGATIVE_INFINITY&&ox<Math.POSITIVE_INFINITY&&oy>Math.NEGATIVE_INFINITY&&oy<Math.POSITIVE_INFINITY&&oz>Math.NEGATIVE_INFINITY&&oz<Math.POSITIVE_INFINITY))throw "蒙皮顶点包含无效数值";
			if(ox<minX)minX=ox;if(oy<minY)minY=oy;if(oz<minZ)minZ=oz;
			if(ox>maxX)maxX=ox;if(oy>maxY)maxY=oy;if(oz>maxZ)maxZ=oz;
			output[offset] = ox;
			output[offset + 1] = oy;
			output[offset + 2] = oz;
			Math3D.transformNormal(blended, restNormals[offset], restNormals[offset + 1], restNormals[offset + 2], normals, offset);
			if(!Math3D.finite(normals[offset])||!Math3D.finite(normals[offset+1])||!Math3D.finite(normals[offset+2]))throw "蒙皮法线包含无效数值";
			if (updateTangents) {
				var t = vertex * 4;
				Math3D.transformTangent(blended, restTangents[t], restTangents[t + 1], restTangents[t + 2], restTangents[t + 3],
					normals[offset], normals[offset + 1], normals[offset + 2], tangents, t);
				for(i in 0...4)if(!Math3D.finite(tangents[t+i]))throw "蒙皮切线包含无效数值";
				if(Math.abs(tangents[t+3])!=1||tangents[t]*tangents[t]+tangents[t+1]*tangents[t+1]+tangents[t+2]*tangents[t+2]<1e-12)throw "蒙皮切线方向或手性无效";
			}
		}
		geometry.commitSkinUpdate(minX,minY,minZ,maxX,maxY,maxZ);
	}
}
