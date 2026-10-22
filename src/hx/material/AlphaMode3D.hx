package hx.material;

/** 不透明、阈值裁剪与透明混合三种绘制阶段。 */
enum abstract AlphaMode3D(Int) from Int to Int {
	/** 不透明绘制阶段。 */
	var OPAQUE = 0;

	/** 按 alphaCutoff 裁剪透明片元。 */
	var MASK = 1;

	/** 透明混合绘制阶段，按渲染器规则排序。 */
	var BLEND = 2;
}
