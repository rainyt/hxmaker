package hx.particle;

/**
 * 创建模式
 */
enum abstract ParticleCreateMode(Int) to Int from Int {
	/**
	 * 矩形
	 */
	var RECT = 0;

	/**
	 * 圆形
	 */
	var CIRCLE = 1;
}
