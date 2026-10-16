package hx.material;

/** 与 glTF 采样常量一致的纹理包裹模式。 */
enum abstract TextureWrap3D(Int) from Int to Int {
	var CLAMP = 33071;
	var REPEAT = 10497;
	var MIRROR = 33648;
}
