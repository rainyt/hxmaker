package hx.render3d;

/** 主场景几何缓存策略；静态对象被修改后仍会自动失效。 */
enum abstract GeometryMobility3D(Int) {
	var STATIC = 0;
	var DYNAMIC = 1;
	/** 变化时立即动态，持续静止后转静态。 */
	var AUTO = 2;
}
