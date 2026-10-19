package hx.render3d;

/** 最近一次三维重绘的数据；最终合成次数在每次 GPU 回调更新。 */
class Scene3DStats {
	/** 距离雾内嵌在原绘制通道，不增加独立批次或纹理。 */
	public var fogStatus:String = "关闭";
	/** 天空通道独立计数，不计入网格批次；纹理为借用资源估算。 */
	public var skyboxStatus:String = "关闭";
	public var skyboxDrawCalls:Int = 0;
	public var skyboxTextureBytes:Int = 0;
	/** IBL 使用状态及借用图集上传尺寸估算；不计入离屏目标显存。 */
	public var environmentStatus:String = "关闭";
	public var environmentTextureBytes:Int = 0;
	/** 最近绘制实际使用的灯光数及因数量限制跳过的灯光数。 */
	public var activeLights:Int = 0;
	public var skippedLights:Int = 0;

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

	/** 主三维及可选软粒子深度预绘制 CPU 墙钟耗时，单位毫秒。 */
	public var mainCpuMs:Float = 0;

	/** 合成到二维目标的 CPU 墙钟耗时，单位毫秒。 */
	public var compositeCpuMs:Float = 0;

	/** 泛光提取与模糊 CPU 提交耗时；不是 GPU 时间。 */
	public var postProcessCpuMs:Float = 0;
	public var bloomDrawCalls:Int = 0;
	public var bloomTargetBytes:Int = 0;
	public var bloomStatus:String = "关闭";
	public var softDepthDrawCalls:Int = 0;
	public var softDepthTriangles:Int = 0;
	public var softDepthUploadedBytes:Int = 0;
	public var softDepthTargetBytes:Int = 0;
	public var softParticleStatus:String = "关闭";

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

	/** 最近一次场景重绘是否复用已有阴影贴图。 */
	public var shadowCacheHit:Bool = false;

	/** 最近一次阴影通道实际绘制批次数。 */
	public var shadowDrawCalls:Int = 0;

	/** 最近一次阴影通道提交的三角形数。 */
	public var shadowTriangles:Int = 0;

	/** 最近一次阴影通道上传字节数。 */
	public var shadowUploadedBytes:Int = 0;
	/** 阴影上传字节数中的索引部分，拓扑不变时应为零。 */
	public var shadowIndexUploadedBytes:Int = 0;

	/** 本次阴影重绘复用及重建几何的级联数量，与阴影贴图缓存分别统计。 */
	public var shadowGeometryCacheHits:Int = 0;
	public var shadowGeometryRebuilds:Int = 0;
	/** 当前阴影几何 GPU 缓冲的预留容量，不含深度贴图及 CPU 副本。 */
	public var shadowGeometryBytes:Int = 0;
	/** 最近重绘的静态与动态阴影几何实际上传量；动态数据仅上传一次供各级联共用。 */
	public var shadowStaticUploadedBytes:Int = 0;
	public var shadowDynamicUploadedBytes:Int = 0;
	/** 静态重建按级联计数，动态重建按对象组计数。 */
	public var shadowStaticGeometryRebuilds:Int = 0;
	public var shadowDynamicGeometryRebuilds:Int = 0;

	/** 阴影目标估算显存字节数。 */
	public var shadowMapBytes:Int = 0;

	/** 实际使用的阴影贴图边长，单位为像素。 */
	public var shadowMapSize:Int = 0;

	/** 实际阴影级联数、深度位数及每级世界纹素尺寸，供画质诊断。 */
	public var shadowCascades:Int = 0;
	public var shadowDepthBits:Int = 0;
	public var shadowWorldTexels:Array<Float> = [];

	/** 实际取景模式；紧凑和手动范围没有相机距离截止，距离值为 0。 */
	public var shadowFitMode:String = "关闭";
	public var shadowEffectiveDistance:Float = 0;
	public var shadowEffectiveFilter:Int = 0;
	public var shadowEffectiveFilterRadius:Float = 0;
	/** 本次重绘各级是否重新提交，以及实际使用的归一化偏差。 */
	public var shadowCascadeUpdated:Array<Bool> = [];
	public var shadowDepthBiases:Array<Float> = [];
	public var shadowSlopeBiases:Array<Float> = [];
	public var shadowDegradation:String = "";

	/** 阴影启用、关闭或后端回退原因的中文说明。 */
	public var shadowStatus:String = "关闭";

	/** 主通道按原因累计的拆批次数，由后端维护。 */
	public var splitReasons:Map<String, Int> = [];

	/** 主场景几何缓存统计，字节数为实际上传或预留 GPU 容量。 */
	public var geometryStaticUploadedBytes:Int = 0;
	public var geometryDynamicUploadedBytes:Int = 0;
	public var geometryIndexUploadedBytes:Int = 0;
	public var geometryCacheBytes:Int = 0;
	public var geometryRebuilds:Int = 0;
	public var geometryCacheHits:Int = 0;
	/** 当前 AUTO 网格数和场景累计切换次数，不随重绘清零。 */
	public var autoStaticMeshes:Int = 0;
	public var autoDynamicMeshes:Int = 0;
	public var autoMobilityTransitions:Int = 0;

	/** 创建归零的绘制统计。 */
	public function new() {}

	/** 重置绘制计数和拆批原因；不清除回调编号、目标尺寸及计时字段。 */
	public function reset():Void {
		geometryStaticUploadedBytes = geometryDynamicUploadedBytes = geometryIndexUploadedBytes = geometryCacheBytes = geometryRebuilds = geometryCacheHits = 0;
		fogStatus = "关闭";
		environmentStatus = "关闭"; environmentTextureBytes = 0;
		skyboxStatus = "关闭"; skyboxDrawCalls = 0; skyboxTextureBytes = 0;
		activeLights = skippedLights = 0;
		postProcessCpuMs = 0; bloomDrawCalls = bloomTargetBytes = 0; bloomStatus = "关闭";
		softDepthDrawCalls = softDepthTriangles = softDepthUploadedBytes = softDepthTargetBytes = 0;
		softParticleStatus = "关闭";
		drawCalls = triangles = visibleMeshes = culledMeshes = uploadedBytes = textureSlots = compositeDrawCalls = 0;
		shadowIndexUploadedBytes = shadowDrawCalls = shadowTriangles = shadowUploadedBytes = shadowMapBytes = shadowMapSize = 0;
		shadowGeometryCacheHits = shadowGeometryRebuilds = shadowGeometryBytes = 0;
		shadowStaticUploadedBytes = shadowDynamicUploadedBytes = 0;
		shadowStaticGeometryRebuilds = shadowDynamicGeometryRebuilds = 0;
		shadowStatus = "关闭"; shadowCacheHit = false;
		shadowCascades = shadowDepthBits = 0; shadowWorldTexels = [];
		shadowFitMode = "关闭"; shadowEffectiveDistance = 0; shadowEffectiveFilter = 0; shadowEffectiveFilterRadius = 0;
		shadowCascadeUpdated = []; shadowDepthBiases = []; shadowSlopeBiases = []; shadowDegradation = "";
		splitReasons.clear();
	}

	/** 按原因累加一次拆批记录。 */
	public function split(reason:String):Void {
		var count = splitReasons.get(reason);
		splitReasons.set(reason, count == null ? 1 : count + 1);
	}
}
