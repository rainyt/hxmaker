package hx.render3d;

/** 最近一次三维重绘的数据；最终合成次数在每次 GPU 回调更新。 */
class Scene3DStats {
	/** 成功完成的 GPU 回调编号；静态纹理复用时也递增，不是主场景重绘次数。 */
	public var renderId:Int = 0;
	public var redrawId:Int = 0;
	public var redrawThisFrame:Bool = false;
	public var profileReady:Bool = false;
	/** 包含状态保护、三维绘制、二维合成与恢复，单位毫秒；不是 GPU 执行时间。 */
	public var renderCpuMs:Float = 0;
	public var shadowCpuMs:Float = 0;
	public var mainCpuMs:Float = 0;
	public var compositeCpuMs:Float = 0;
	public var stateCpuMs:Float = 0;
	public var targetWidth:Int = 0;
	public var targetHeight:Int = 0;
	public var drawCalls:Int = 0;
	public var triangles:Int = 0;
	public var visibleMeshes:Int = 0;
	public var culledMeshes:Int = 0;
	public var uploadedBytes:Int = 0;
	public var textureSlots:Int = 0;
	public var compositeDrawCalls:Int = 0;
	public var targetBytes:Int = 0;
	public var shadowDrawCalls:Int = 0;
	public var shadowTriangles:Int = 0;
	public var shadowUploadedBytes:Int = 0;
	public var shadowMapBytes:Int = 0;
	public var shadowMapSize:Int = 0;
	public var shadowStatus:String = "关闭";
	public var splitReasons:Map<String, Int> = [];
	public function new() {}
	public function reset():Void {
		drawCalls = triangles = visibleMeshes = culledMeshes = uploadedBytes = textureSlots = compositeDrawCalls = 0;
		shadowDrawCalls = shadowTriangles = shadowUploadedBytes = shadowMapBytes = shadowMapSize = 0; shadowStatus = "关闭";
		splitReasons.clear();
	}
	public function split(reason:String):Void {
		var count = splitReasons.get(reason);
		splitReasons.set(reason, count == null ? 1 : count + 1);
	}
}
