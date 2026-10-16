package hx.formats.gltf;

import hx.animation3d.AnimationClip3D;
import haxe.io.Bytes;

/** 解析后的源数据；实例只读使用，所有可变姿态与顶点另行分配。 */
typedef GltfData = {
	var nodes:Array<GltfNodeData>;
	var parents:Array<Int>;
	var scenes:Array<Array<Int>>;
	var scene:Int;
	var meshes:Array<Array<GltfPrimitiveData>>;
	var materials:Array<GltfMaterialData>;
	var images:Array<GltfImageData>;
	var textures:Array<GltfTextureData>;
	var skins:Array<GltfSkinData>;
	var animations:Array<AnimationClip3D>;
	var warnings:Array<String>;
}

typedef GltfNodeData = {
	var name:String;
	var children:Array<Int>;
	var mesh:Int;
	var skin:Int;
	var matrix:Array<Float>;
	var translation:Array<Float>;
	var rotation:Array<Float>;
	var scale:Array<Float>;
}

typedef GltfPrimitiveData = {
	var positions:Array<Float>;
	var normals:Array<Float>;
	var uvs:Array<Float>;
	var indices:Array<Int>;
	var joints:Array<Int>;
	var weights:Array<Float>;
	var material:Int;
}

typedef GltfMaterialData = {
	var name:String;
	var baseColorFactor:Array<Float>;
	var metallicFactor:Float;
	var roughnessFactor:Float;
	var emissiveFactor:Array<Float>;
	var color:Int;
	var opacity:Float;
	var alphaMode:String;
	var alphaCutoff:Float;
	var doubleSided:Bool;
	var baseColorTexture:Int;
}

/** 仅保存 GLB 内嵌图片字节，图片解码通过资产 Future 完成。 */
typedef GltfImageData = {
	var name:String;
	var mimeType:String;
	var bytes:Bytes;
}

/** 采样参数与图片分离，同一图片可以由不同材质重复引用。 */
typedef GltfTextureData = {
	var source:Int;
	var wrapU:Int;
	var wrapV:Int;
	var smoothing:Bool;
	var minSmoothing:Bool;
}

typedef GltfSkinData = {
	var joints:Array<Int>;
	var inverseBindMatrices:Array<Array<Float>>;
}
