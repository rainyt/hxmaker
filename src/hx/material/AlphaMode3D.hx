package hx.material;

/** 不透明、阈值裁剪与透明混合三种绘制阶段。 */
enum abstract AlphaMode3D(Int) from Int to Int {
	var OPAQUE = 0;
	var MASK = 1;
	var BLEND = 2;
}
