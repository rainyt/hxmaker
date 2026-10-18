package hx.render3d;

/** 距离雾模式；字符串值同时作为场景配置的稳定标识。 */
enum abstract FogMode3D(String) from String to String {
	var LINEAR = "linear";
	var EXP = "exp";
	var EXP2 = "exp2";
}
