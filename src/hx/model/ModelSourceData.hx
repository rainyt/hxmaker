package hx.model;

import haxe.io.Bytes;
import hx.animation3d.AnimationClip3D.AnimationTrack3D;
import hx.material.AlphaMode3D;
import hx.material.CullMode3D;
import hx.material.TextureWrap3D;

/** 导入器输出的中立数据。构建器复制输入，调用方仍拥有源数组。 */
typedef ModelSourceData = {
	var sourceFormat:String;
	var nodes:Array<ModelNodeData>;
	var scenes:Array<Array<Int>>;
	var scene:Int;
	var meshes:Array<Array<ModelPrimitiveSource>>;
	var materials:Array<ModelMaterialData>;
	var images:Array<ModelImageSource>;
	var textures:Array<ModelTextureData>;
	var skins:Array<ModelSkinData>;
	var animations:Array<ModelAnimationData>;
	var warnings:Array<String>;
}

/** 节点索引在构建过程中保持不变；静态矩阵与动画 TRS 互斥。 */
typedef ModelNodeData = {
	var name:String;
	var children:Array<Int>;
	var mesh:Int;
	var skin:Int;
	/** 列向量、列主序局部矩阵；使用 TRS 时为 null。 */
	var matrix:Array<Float>;
	var translation:Array<Float>;
	/** 四元数分量顺序为 x/y/z/w。 */
	var rotation:Array<Float>;
	var scale:Array<Float>;
}

/** 三角形图元；位置和法线每顶点三项，UV 两项，关节与权重四项。 */
typedef ModelPrimitiveSource = {
	var positions:Array<Float>;
	/** 空数组表示需要生成法线。 */
	var normals:Array<Float>;
	/** 可选切线，每顶点 XYZ 与正负手性 W；缺省按需生成。 */
	@:optional var tangents:Array<Float>;
	var uvs:Array<Float>;
	var indices:Array<Int>;
	var joints:Array<Int>;
	var weights:Array<Float>;
	var material:Int;
}

/** 引擎材质参数；PBR 因子通过 Model3DOptions.pbrEnabled 显式启用。 */
typedef ModelMaterialData = {
	var name:String;
	var baseColorFactor:Array<Float>;
	var metallicFactor:Float;
	var roughnessFactor:Float;
	var emissiveFactor:Array<Float>;
	var color:Int;
	var opacity:Float;
	var alphaMode:AlphaMode3D;
	var alphaCutoff:Float;
	var cullMode:CullMode3D;
	var baseColorTexture:Int;
	@:optional var metallicRoughnessTexture:Int;
	@:optional var normalTexture:Int;
	@:optional var occlusionTexture:Int;
	@:optional var emissiveTexture:Int;
	@:optional var normalScale:Float;
	@:optional var occlusionStrength:Float;
}

/** 原始图片字节必须保留，供后端解码及未来发布文件写入使用。 */
typedef ModelImageSource = {
	var name:String;
	var mimeType:String;
	var bytes:Bytes;
}

/** 纹理采样与图片分离，多个采样定义可以引用同一张图片。 */
typedef ModelTextureData = {
	var source:Int;
	var wrapU:TextureWrap3D;
	var wrapV:TextureWrap3D;
	var smoothing:Bool;
	var minSmoothing:Bool;
	/** 可选完整缩小过滤；缺省兼容旧数据的 minSmoothing。 */
	@:optional var minFilter:Null<Int>;
}

/** 关节矩阵统一为模型空间关节全局矩阵乘逆绑定矩阵。 */
typedef ModelSkinData = {
	var joints:Array<Int>;
	var inverseBindMatrices:Array<Array<Float>>;
}

/** 纯数据动画定义，不持有播放器或运行时片段对象。 */
typedef ModelAnimationData = {
	var name:String;
	/** 时间单位为秒，轨道只支持节点 TRS 与 LINEAR/STEP。 */
	var tracks:Array<AnimationTrack3D>;
}
