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
	private var gpuRequested:Bool;
	private static var nextId:Int = 0;
	private var id:Int;

	/** 借用导入蒙皮数据并创建实例独立的关节矩阵缓冲。 */
	public function new(data:ModelSkinData, gpuRequested:Bool = false) {
		this.gpuRequested = gpuRequested;
		id=++nextId;
		this.data = data;
		inverses = [for (matrix in data.inverseBindMatrices) new Matrix3D(matrix)];
		palette = [for (_ in data.joints) new Matrix3D()];
	}

	/** 刚性单关节网格直接复用网格矩阵；其他网格使用实例独立的 CPU 顶点。 */
	public function bind(mesh:MeshObject, primitive:ModelPrimitiveData):Void {
		bindings.push(new SkinBinding3D(mesh, primitive, gpuRequested, id));
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
		for(binding in bindings)binding.dispose();
		data = null;
		inverses = [];
		palette = [];
		bindings = [];
	}
}

class SkinBinding3D {
	private var mesh:MeshObject;
	public var source(default,null):ModelPrimitiveData;
	public var palette(default,null):Array<Matrix3D>;
	public var requested(default,null):Bool;
	public var skinId(default,null):Int;
	public var geometry(default,null):hx.geometry.Geometry3D;
	public var dataVersion(default,null):Int;
	/** 由后端按当前设备、材质和空间变换协商；始终可回退 CPU。 */
	public var gpuEnabled:Bool = false;
	private var normalDirty:Bool = false;
	private var rigidJoint:Int = -1;
	private var lastMatrix:Array<Float>;
	private var restNormals:Array<Float>;
	private var restTangents:Array<Float>;
	private var blended:Array<Float> = [for (_ in 0...16) 0.];

	/** 借用网格及源图元，选择刚性关节或实例 CPU 蒙皮路径。 */
	public function new(mesh:MeshObject, source:ModelPrimitiveData, requested:Bool, skinId:Int) {
		this.requested = requested;
		this.skinId=skinId;geometry=mesh.geometry;dataVersion=geometry.dataVersion;
		this.mesh = mesh;
		this.source = source;
		rigidJoint = source.rigidJoint;
		// 原始法线属于只读资产，输出法线由实例几何独立持有。
		if (rigidJoint < 0) {
			restNormals = source.normals;
			mesh.skinBinding = this;
			mesh.geometry.normalReader = materializeNormals;
		}
	}

	/** 使用当前关节矩阵调色板更新绑定网格的实例顶点或刚性变换。 */
	public function update(palette:Array<Matrix3D>, forceCpu:Bool = false):Void {
		this.palette = palette;
		normalDirty = false;
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
		if(gpuEnabled&&!forceCpu){updatePositions(palette);normalDirty=true;return;}
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
			// 先融合仿射矩阵，再变换顶点；位置与法线共享同一份融合结果。
			var b0=0.,b1=0.,b2=0.,b4=0.,b5=0.,b6=0.,b8=0.,b9=0.,b10=0.,b12=0.,b13=0.,b14=0.;
			for (slot in 0...4) {
				var i = vertex * 4 + slot, weight = source.weights[i];
				if (weight == 0) continue;
				var m = palette[source.joints[i]].rawData;
				b0+=m[0]*weight;b1+=m[1]*weight;b2+=m[2]*weight;
				b4+=m[4]*weight;b5+=m[5]*weight;b6+=m[6]*weight;
				b8+=m[8]*weight;b9+=m[9]*weight;b10+=m[10]*weight;
				b12+=m[12]*weight;b13+=m[13]*weight;b14+=m[14]*weight;
			}
			blended[0]=b0;blended[1]=b1;blended[2]=b2;
			blended[4]=b4;blended[5]=b5;blended[6]=b6;
			blended[8]=b8;blended[9]=b9;blended[10]=b10;
			var ox=b0*x+b4*y+b8*z+b12,oy=b1*x+b5*y+b9*z+b13,oz=b2*x+b6*y+b10*z+b14;

			// 与旧校验保持有限位置约束，在写入时顺便计算包围盒。
			if(!(ox>Math.NEGATIVE_INFINITY&&ox<Math.POSITIVE_INFINITY&&oy>Math.NEGATIVE_INFINITY&&oy<Math.POSITIVE_INFINITY&&oz>Math.NEGATIVE_INFINITY&&oz<Math.POSITIVE_INFINITY))throw "蒙皮顶点包含无效数值";
			if(ox<minX)minX=ox;if(oy<minY)minY=oy;if(oz<minZ)minZ=oz;
			if(ox>maxX)maxX=ox;if(oy>maxY)maxY=oy;if(oz>maxZ)maxZ=oz;
			if(!forceCpu){output[offset] = ox;output[offset + 1] = oy;output[offset + 2] = oz;}
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
		if(!forceCpu)geometry.commitSkinUpdate(minX,minY,minZ,maxX,maxY,maxZ);
	}
	/** 解除延迟读取回调和借用数据；仍存活的网格保留最后一次姿态。 */
	@:allow(hx.animation3d.Skin3D)
	private function dispose():Void {
		if(mesh!=null&&mesh.skinBinding==this){
			materializeNormals();mesh.skinBinding=null;
		}
		if(geometry!=null)geometry.normalReader=null;
		gpuEnabled=false;palette=null;source=null;restNormals=null;restTangents=null;mesh=null;geometry=null;
	}
	private function materializeNormals():Void {
		if(!normalDirty||mesh.isDisposed)return;
		normalDirty=false;
		update(palette,true);
	}
	/** 保留精确 CPU 顶点和边界，法线在 GPU 计算，CPU 查询法线时才补算。 */
	private function updatePositions(palette:Array<Matrix3D>):Void {
		var input=source.positions,output=mesh.geometry.positions;
		var minX=Math.POSITIVE_INFINITY,minY=minX,minZ=minX,maxX=Math.NEGATIVE_INFINITY,maxY=maxX,maxZ=maxX;
		for(vertex in 0...Std.int(input.length/3)){
			var offset=vertex*3,x=input[offset],y=input[offset+1],z=input[offset+2],ox=0.,oy=0.,oz=0.;
			for(slot in 0...4){
				var i=vertex*4+slot,w=source.weights[i];if(w==0)continue;
				var m=palette[source.joints[i]].rawData;
				ox+=(m[0]*x+m[4]*y+m[8]*z+m[12])*w;
				oy+=(m[1]*x+m[5]*y+m[9]*z+m[13])*w;
				oz+=(m[2]*x+m[6]*y+m[10]*z+m[14])*w;
			}
			if(!(ox>Math.NEGATIVE_INFINITY&&ox<Math.POSITIVE_INFINITY&&oy>Math.NEGATIVE_INFINITY&&oy<Math.POSITIVE_INFINITY&&oz>Math.NEGATIVE_INFINITY&&oz<Math.POSITIVE_INFINITY))throw "蒙皮顶点包含无效数值";
			output[offset]=ox;output[offset+1]=oy;output[offset+2]=oz;
			if(ox<minX)minX=ox;if(oy<minY)minY=oy;if(oz<minZ)minZ=oz;
			if(ox>maxX)maxX=ox;if(oy>maxY)maxY=oy;if(oz>maxZ)maxZ=oz;
		}
		mesh.geometry.commitSkinUpdate(minX,minY,minZ,maxX,maxY,maxZ);
	}

}
