package hx.light;

/** 阴影过滤质量；硬阴影一次比较，PCF 四次比较后按亚纹素位置加权。 */
enum abstract ShadowFilter3D(Int) from Int to Int {
	var HARD = 0;
	var PCF4 = 1;
}
