package hx.material;

/** 与 glTF 采样常量一致的纹理包裹模式。 */
enum abstract TextureWrap3D(Int) from Int to Int {
	/** 边缘钳制，超出范围的 UV 使用边缘颜色。 */
	var CLAMP = 33071;

	/** 重复纹理，使用前需满足后端及图片尺寸约束。 */
	var REPEAT = 10497;

	/** 镜像重复纹理，使用前需满足后端及图片尺寸约束。 */
	var MIRROR = 33648;
}
