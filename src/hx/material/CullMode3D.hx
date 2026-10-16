package hx.material;

/** 网格正反面的剔除方式。 */
enum abstract CullMode3D(Int) from Int to Int {
	/** 不剔除面，双面均可绘制。 */
	var NONE = 0;

	/** 剔除背面。 */
	var BACK = 1;

	/** 剔除正面。 */
	var FRONT = 2;
}
