package hx.utils;

/**
 * 上一轮已完成的引擎帧快照，时间单位为秒。
 * 绘制计数在下一轮计时开始时收齐，包含此前执行的延迟渲染回调。
 * 耗时仅覆盖 statsCpuStart 到 statsCpu，不代表完整渲染时间或 GPU 执行耗时。
 */
@:allow(hx.utils.ContextStats)
class ContextStatsFrame {
	public var id(default, null):Int = 0;
	public var frameRate(default, null):Int = 0;
	public var interval(default, null):Float = 0;
	public var usedTime(default, null):Float = 0;
	public var drawCall(default, null):Int = 0;
	/** 提交的索引顶点数，不是去重后的几何顶点数。 */
	public var vertexCount(default, null):Int = 0;
	public var visibleDisplayCounts(default, null):Int = 0;
	public var spineUpdateCount(default, null):Int = 0;
	public var graphicRenderCount(default, null):Int = 0;
	public var timerTaskCount(default, null):Int = 0;
	public var blendModeFilterDrawCall(default, null):Int = 0;

	private function new() {}
}
