package hx.formats.gltf;

import hx.animation3d.AnimationClip3D;

/** 解析后的源数据；实例只读使用，所有可变姿态与顶点另行分配。 */
typedef GltfData = {
	var nodes:Array<GltfNodeData>;
	var parents:Array<Int>;
	var scenes:Array<Array<Int>>;
	var scene:Int;
	var meshes:Array<Array<GltfPrimitiveData>>;
	var materials:Array<GltfMaterialData>;
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
}

typedef GltfSkinData = {
	var joints:Array<Int>;
	var inverseBindMatrices:Array<Array<Float>>;
}
