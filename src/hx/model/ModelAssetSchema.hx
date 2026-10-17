package hx.model;

/** 中立数据与构建规则独立版本化；未来二进制容器还需单独定义文件版本。 */
class ModelAssetSchema {
	/** 数据语义版本：右手系、Y 向上、米制、列向量与列主序矩阵。 */
	public static inline var DATA_VERSION:Int = 1;

	/** 构建算法版本；预处理规则改变时递增，用于未来资源构建缓存失效。 */
	public static inline var BUILD_VERSION:Int = 1;
}
