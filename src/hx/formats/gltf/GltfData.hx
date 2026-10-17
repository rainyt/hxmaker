package hx.formats.gltf;

import hx.animation3d.AnimationClip3D;
import haxe.io.Bytes;

/** glTF 解析源数据；保留源格式语义，经过 GlbImporter 构建中立资产后再供实例使用。 */
typedef GltfData = {
	/** 源节点数据，按 GLB 节点索引排列。 */
	var nodes:Array<GltfNodeData>;

	/** 各节点父索引，无父节点时为 -1。 */
	var parents:Array<Int>;

	/** 每个源场景的根节点索引集合。 */
	var scenes:Array<Array<Int>>;

	/** 默认源场景索引。 */
	var scene:Int;

	/** 按网格定义排列的图元集合。 */
	var meshes:Array<Array<GltfPrimitiveData>>;

	/** 导入材质定义集合。 */
	var materials:Array<GltfMaterialData>;

	/** 内嵌图片字节定义，尚未经过位图解码。 */
	var images:Array<GltfImageData>;

	/** 纹理采样定义，引用 images 索引。 */
	var textures:Array<GltfTextureData>;

	/** 蒙皮定义集合。 */
	var skins:Array<GltfSkinData>;

	/** 共享只读动画片段。 */
	var animations:Array<AnimationClip3D>;

	/** 兼容性和降级处理的中文提示。 */
	var warnings:Array<String>;
}

/** 源节点局部变换与场景引用数据。 */
typedef GltfNodeData = {
	/** 源节点名称，允许重名。 */
	var name:String;

	/** 直接子节点的源索引。 */
	var children:Array<Int>;

	/** 引用的网格定义索引，无网格时为 -1。 */
	var mesh:Int;

	/** 引用的蒙皮索引，无蒙皮时为 -1。 */
	var skin:Int;

	/** 精确局部矩阵，列优先 16 项；采用 TRS 时为 null。 */
	var matrix:Array<Float>;

	/** 局部平移 x/y/z。 */
	var translation:Array<Float>;

	/** 局部旋转四元数 x/y/z/w。 */
	var rotation:Array<Float>;

	/** 局部缩放 x/y/z。 */
	var scale:Array<Float>;
}

/** 源三角形图元数据；实例化后为可变顶点另行分配数组。 */
typedef GltfPrimitiveData = {
	/** 局部顶点位置，每顶点连续 3 项。 */
	var positions:Array<Float>;

	/** 局部顶点法线，每顶点连续 3 项；缺失时由实例生成。 */
	var normals:Array<Float>;

	/** 第一套 UV，每顶点连续 2 项。 */
	var uvs:Array<Float>;

	/** 三角形顶点索引，每三项组成一个三角形。 */
	var indices:Array<Int>;

	/** 顶点关节索引，每顶点连续 4 项。 */
	var joints:Array<Int>;

	/** 顶点关节权重，每顶点连续 4 项。 */
	var weights:Array<Float>;

	/** 引用的材质索引，无指定材质时为 -1。 */
	var material:Int;
}

/** 源材质参数；保存参数不代表当前渲染已支持全部 PBR 特性。 */
typedef GltfMaterialData = {
	/** 源材质名称。 */
	var name:String;

	/** 线性空间基础色 RGBA 因子。 */
	var baseColorFactor:Array<Float>;

	/** 源金属度，仅保存定义，当前基础渲染不执行 PBR。 */
	var metallicFactor:Float;

	/** 源粗糙度，仅保存定义，当前基础渲染不执行 PBR。 */
	var roughnessFactor:Float;

	/** 源自发光 RGB 因子，当前基础渲染尚不应用。 */
	var emissiveFactor:Array<Float>;

	/** 基础色转换为显示编码后的 RGB 整数。 */
	var color:Int;

	/** 基础色 Alpha，不透明度范围 0 至 1。 */
	var opacity:Float;

	/** 源透明模式 OPAQUE、MASK 或 BLEND。 */
	var alphaMode:String;

	/** MASK 模式透明裁剪阈值。 */
	var alphaCutoff:Float;

	/** 是否双面绘制。 */
	var doubleSided:Bool;

	/** 基础色纹理索引，无贴图时为 -1。 */
	var baseColorTexture:Int;
}

/** 仅保存 GLB 内嵌图片字节，图片解码通过资产 Future 完成。 */
typedef GltfImageData = {
	/** 图片名称或解析时生成的标识。 */
	var name:String;

	/** 内嵌图片 MIME 类型，支持 PNG 或 JPEG。 */
	var mimeType:String;

	/** 内嵌图片的二进制字节，由资产 Future 继续解码。 */
	var bytes:Bytes;
}

/** 采样参数与图片分离，同一图片可以由不同材质重复引用。 */
typedef GltfTextureData = {
	/** 内嵌图片定义索引。 */
	var source:Int;

	/** U 方向 glTF 纹理包裹常量。 */
	var wrapU:Int;

	/** V 方向 glTF 纹理包裹常量。 */
	var wrapV:Int;

	/** 放大时是否线性过滤。 */
	var smoothing:Bool;

	/** 缩小时是否使用基础层线性过滤，不表示已生成 mipmap。 */
	var minSmoothing:Bool;
}

/** 源蒙皮关节与逆绑定矩阵，供模型实例只读使用。 */
typedef GltfSkinData = {
	/** 按蒙皮局部关节编号排列的源节点索引。 */
	var joints:Array<Int>;

	/** 对应各关节的逆绑定矩阵，每个矩阵列优先 16 项。 */
	var inverseBindMatrices:Array<Array<Float>>;
}
