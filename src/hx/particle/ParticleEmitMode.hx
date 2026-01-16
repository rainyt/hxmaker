package hx.particle;

/**
 * 粒子发射模式
 */
enum abstract ParticleEmitMode(Int) to Int from Int {
	/**
	 * 根据点的位置自由发射粒子
	 */
	var POINT = 0;

	/**
	 * 根据中心点与坐标点的方向发射粒子
	 */
	var CIRCLE = 1;
}
