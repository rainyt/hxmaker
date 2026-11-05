package hx.display;

/** 可选的后端生命周期查询，供缓存维护判断可获取状态和渲染持有。 */
interface IBitmapDataLifetime {
	/** 是否允许新的消费者取得纹理。 */
	public function isAvailable():Bool;
	/** 当前仍持有根纹理的快照数量。 */
	public function getRenderReferences():Int;
}
