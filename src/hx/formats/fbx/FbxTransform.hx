package hx.formats.fbx;

import hx.geom.Matrix3D;
import hx.render3d.Math3D;

/** 静态 FBX 的变换求值；构建完整矩阵，避免用欧拉角或 TRS 分解损失枢轴信息。 */
class FbxTransform {
	public static function local(t:Array<Float>, r:Array<Float>, s:Array<Float>, order:Int, pre:Array<Float>, post:Array<Float>,
		rotationOffset:Array<Float>, rotationPivot:Array<Float>, scaleOffset:Array<Float>, scalePivot:Array<Float>):Matrix3D {
		var inversePost = rotation(post, 0);
		if (!inversePost.invert()) throw "FBX 后置旋转矩阵不可逆";
		var parts = [translation(t), translation(rotationOffset), translation(rotationPivot), rotation(pre, 0), rotation(r, order),
			inversePost, translation(negative(rotationPivot)), translation(scaleOffset), translation(scalePivot), scale(s),
			translation(negative(scalePivot))];
		var result = new Matrix3D();
		for (part in parts) result = Math3D.multiply(result, part);
		return result;
	}

	public static function geometric(t:Array<Float>, r:Array<Float>, s:Array<Float>):Matrix3D {
		return Math3D.multiply(Math3D.multiply(translation(t), rotation(r, 0)), scale(s));
	}

	/** FBX FrontAxis 描述朝前方向，引擎以相反方向作为正 Z。 */
	public static function basis(right:Int, rightSign:Int, up:Int, upSign:Int, front:Int, frontSign:Int, meters:Float):Matrix3D {
		if (right < 0 || right > 2 || up < 0 || up > 2 || front < 0 || front > 2 || right == up || right == front || up == front
			|| Math.abs(rightSign) != 1 || Math.abs(upSign) != 1 || Math.abs(frontSign) != 1 || !Math.isFinite(meters) || meters <= 0)
			throw "FBX 坐标轴或单位定义无效";
		var data = [for (_ in 0...16) 0.];
		data[right * 4] = rightSign * meters;
		data[up * 4 + 1] = upSign * meters;
		data[front * 4 + 2] = -frontSign * meters;
		data[15] = 1;
		return new Matrix3D(data);
	}

	private static function translation(value:Array<Float>):Matrix3D {
		var matrix = new Matrix3D();
		for (axis in 0...3) matrix.rawData[12 + axis] = value[axis];
		return matrix;
	}

	private static function scale(value:Array<Float>):Matrix3D {
		var matrix = new Matrix3D();
		for (axis in 0...3) matrix.rawData[axis * 5] = value[axis];
		return matrix;
	}

	private static function negative(value:Array<Float>):Array<Float> return [-value[0], -value[1], -value[2]];

	private static function rotation(value:Array<Float>, order:Int):Matrix3D {
		var orders = ["XYZ", "XZY", "YZX", "YXZ", "ZXY", "ZYX"];
		if (order < 0 || order >= orders.length) throw "FBX 不支持球面旋转顺序";
		var result = new Matrix3D();
		for (index in 0...3) {
			var axis = orders[order].charAt(index), slot = axis == "X" ? 0 : axis == "Y" ? 1 : 2;
			var angle = value[slot] * Math.PI / 180, c = Math.cos(angle), s = Math.sin(angle);
			var matrix = switch (axis) {
				case "X": new Matrix3D([1.,0.,0.,0., 0.,c,s,0., 0.,-s,c,0., 0.,0.,0.,1.]);
				case "Y": new Matrix3D([c,0.,-s,0., 0.,1.,0.,0., s,0.,c,0., 0.,0.,0.,1.]);
				default: new Matrix3D([c,s,0.,0., -s,c,0.,0., 0.,0.,1.,0., 0.,0.,0.,1.]);
			};
			result = Math3D.multiply(matrix, result);
		}
		return result;
	}
}
