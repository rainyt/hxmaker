package hx.render3d;

/** 最近一次三维重绘的数据；最终合成次数在每次 GPU 回调更新。 */
class Scene3DStats {
	/** 成功完成的 GPU 回调编号；静态纹理复用时也递增，不是主场景重绘次数。 */
	public var renderId:Int = 0;

	/** 主三维目标实际重绘编号，不包含静态纹理复用。 */
	public var redrawId:Int = 0;

	/** 本次后端回调是否重新绘制三维目标。 */
	public var redrawThisFrame:Bool = false;

	/** 本次是否提供有效的 CPU 分段计时。 */
	public var profileReady:Bool = false;

	/** 包含状态保护、三维绘制、二维合成与恢复，单位毫秒；不是 GPU 执行时间。 */
	public var renderCpuMs:Float = 0;

	/** 阴影通道 CPU 墙钟耗时，单位毫秒。 */
	public var shadowCpuMs:Float = 0;

	/** 主三维通道 CPU 墙钟耗时，单位毫秒。 */
	public var mainCpuMs:Float = 0;

	/** 合成到二维目标的 CPU 墙钟耗时，单位毫秒。 */
	public var compositeCpuMs:Float = 0;

	/** GL 状态保护总 CPU 耗时，单位毫秒；不代表 GPU 时间。 */
	public var stateCpuMs:Float = 0;

	/** 状态耗时细分；按需快照可能发生在主通道内部，不与各通道耗时相加。 */
	public var stateFlushCpuMs:Float = 0;

	/** GL 状态快照 CPU 耗时，单位毫秒。 */
	public var stateSnapshotCpuMs:Float = 0;

	/** GL 状态恢复 CPU 耗时，单位毫秒。 */
	public var stateRestoreCpuMs:Float = 0;

	/** 采样器与纹理绑定恢复 CPU 耗时，单位毫秒。 */
	public var samplerRestoreCpuMs:Float = 0;

	/** 保护器执行的同步状态查询数量，不包含初始化能力查询及业务诊断探针。 */
	public var stateQueryCount:Int = 0;

	/** 本次状态保护实际涉及的纹理槽位数。 */
	public var stateTextureSlots:Int = 0;

	/** 本次是否仅需保护二维合成所涉及的状态。 */
	public var stateCompositeOnly:Bool = false;

	/** 本次状态保护是否使用顶点数组对象路径。 */
	public var stateVao:Bool = false;

	/** 实际三维离屏目标宽度，单位为像素。 */
	public var targetWidth:Int = 0;

	/** 实际三维离屏目标高度，单位为像素。 */
	public var targetHeight:Int = 0;

	/** 最近一次主三维通道实际绘制批次数，不含阴影及二维合成。 */
	public var drawCalls:Int = 0;

	/** 最近一次主三维通道提交的三角形数。 */
	public var triangles:Int = 0;

	/** 最近一次主三维通道参与绘制的网格数。 */
	public var visibleMeshes:Int = 0;

	/** 最近一次主三维通道被视锥裁剪的网格数。 */
	public var culledMeshes:Int = 0;

	/** 最近一次主三维通道上传的顶点与索引字节数。 */
	public var uploadedBytes:Int = 0;

	/** 最近一次主三维绘制使用的多纹理槽位能力。 */
	public var textureSlots:Int = 0;

	/** 最近一次二维合成的绘制批次数。 */
	public var compositeDrawCalls:Int = 0;

	/** 三维离屏目标估算显存字节数。 */
	public var targetBytes:Int = 0;

	/** 最近一次阴影通道实际绘制批次数。 */
	public var shadowDrawCalls:Int = 0;

	/** 最近一次阴影通道提交的三角形数。 */
	public var shadowTriangles:Int = 0;

	/** 最近一次阴影通道上传字节数。 */
	public var shadowUploadedBytes:Int = 0;

	/** 阴影目标估算显存字节数。 */
	public var shadowMapBytes:Int = 0;

	/** 实际使用的阴影贴图边长，单位为像素。 */
	public var shadowMapSize:Int = 0;

	/** 阴影启用、关闭或后端回退原因的中文说明。 */
	public var shadowStatus:String = "关闭";

	/** 主通道按原因累计的拆批次数，由后端维护。 */
	public var splitReasons:Map<String, Int> = [];

	/** 创建归零的绘制统计。 */
	public function new() {}

	/** 重置绘制计数和拆批原因；不清除回调编号、目标尺寸及计时字段。 */
	public function reset():Void {
		drawCalls = triangles = visibleMeshes = culledMeshes = uploadedBytes = textureSlots = compositeDrawCalls = 0;
		shadowDrawCalls = shadowTriangles = shadowUploadedBytes = shadowMapBytes = shadowMapSize = 0;
		shadowStatus = "关闭";
		splitReasons.clear();
	}

	/** 按原因累加一次拆批记录。 */
	public function split(reason:String):Void {
		var count = splitReasons.get(reason);
		splitReasons.set(reason, count == null ? 1 : count + 1);
	}
}
