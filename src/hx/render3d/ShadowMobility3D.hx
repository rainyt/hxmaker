package hx.render3d;

/** 阴影投射物的几何更新策略；静态提示不禁止后续修改。 */
enum abstract ShadowMobility3D(Int) {
	/** 固定环境：按级联合批缓存，修改世界变换或几何后自动失效。 */
	var STATIC = 0;
	/** 移动物体：缓存局部几何，变换通过矩阵更新，蒙皮数据跨级联复用。 */
	var DYNAMIC = 1;
	/** 与主场景共用活动判定，持续静止后自动转静态。 */
	var AUTO = 2;
}
