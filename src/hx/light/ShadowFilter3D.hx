package hx.light;

/** 阴影过滤质量；PCF 模式对深度比较结果加权，采样次数随质量档位增加。 */
enum abstract ShadowFilter3D(Int) from Int to Int {
	var HARD = 0;
	var PCF4 = 1;
	/** 九次深度比较的三乘三帐篷过滤，配合 shadowFilterRadius 调整柔化程度。 */
	var PCF9 = 2;
}
