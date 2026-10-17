package hx.material;

/** 透明通道的混合方式；不透明与裁剪通道忽略此设置。 */
enum abstract BlendMode3D(Int) from Int to Int {
	/** 预乘透明混合。 */
	var NORMAL = 0;
	/** 按透明度衰减后叠加 RGB，保留目标 alpha，避免遮暗二维背景。 */
	var ADD = 1;
}
