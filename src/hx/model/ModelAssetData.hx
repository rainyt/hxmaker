package hx.model;

import hx.model.ModelSourceData.ModelNodeData;
import hx.model.ModelSourceData.ModelMaterialData;
import hx.model.ModelSourceData.ModelTextureData;
import hx.model.ModelSourceData.ModelSkinData;
import hx.model.ModelSourceData.ModelAnimationData;
import hx.model.ModelSourceData.ModelPrimitiveSource;
import hx.model.ModelSourceData.ModelImageSource;

/**
 * 已构建的只读资产数据；不包含位图解码结果、GPU 句柄或实例状态。
 * 发布格式读写应映射此结构，并校验版本及派生数据；当前尚未实现文件编解码。
 */
typedef ModelAssetData = {
	var dataVersion:Int;
	var buildVersion:Int;
	var sourceFormat:String;
	var nodes:Array<ModelNodeData>;
	var parents:Array<Int>;
	var scenes:Array<Array<Int>>;
	var scene:Int;
	/** 每个场景的父节点优先遍历表；不改变源节点索引。 */
	var sceneNodes:Array<Array<Int>>;
	var meshes:Array<Array<ModelPrimitiveData>>;
	var materials:Array<ModelMaterialData>;
	var images:Array<ModelImageData>;
	var textures:Array<ModelTextureData>;
	var skins:Array<ModelSkinData>;
	var animations:Array<ModelAnimationData>;
	var warnings:Array<String>;
	var stats:ModelBuildStats;
}

/** 运行时图元：数值数组已校验、法线已准备；实例几何缓冲仍独立复制。 */
typedef ModelPrimitiveData = {
	> ModelPrimitiveSource,
	/** 空网格为零项，否则为 minX/minY/minZ/maxX/maxY/maxZ。 */
	var bounds:Array<Float>;
	var triangleCount:Int;
	/** 标记自动法线，使实例几何修改后仍能重新生成法线。 */
	var generatedNormals:Bool;
	/** 全部顶点都刚性绑定同一关节时为局部关节索引，否则为 -1。 */
	var rigidJoint:Int;
}

/** 图片摘要在构建时生成，异步加载复用此摘要进行缓存查找。 */
typedef ModelImageData = {
	> ModelImageSource,
	var contentHash:String;
}

/** 源定义统计，不按节点引用次数累计；不代表实测性能。 */
typedef ModelBuildStats = {
	var vertexCount:Int;
	var triangleCount:Int;
	var primitiveCount:Int;
	var generatedNormalCount:Int;
	var rigidPrimitiveCount:Int;
}
